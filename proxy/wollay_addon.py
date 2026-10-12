"""mitmproxy addon for the Wollay launcher under Wine.

Update downloads from wollay.com stall mid-body under Wine (Wine's Schannel only
does TLS 1.2 and gets stuck receiving some responses). This addon:

1. Prefetches: when the launcher asks for updates (/api/updates/check), the
   request is held back while the addon fetches the same signed manifest
   itself (OpenSSL, TLS 1.3) and downloads every chunk missing from the
   launcher's content-addressed chunk store (file name = sha256 of the
   inflated data), verified against both hashes in the manifest. When the
   launcher's request is then let through, it finds everything locally.
2. Streams every response to the launcher as it arrives instead of buffering
   it. Handing Schannel the 1.6 MB update manifest in one burst stalls it.
3. Keeps a copy of every chunk the launcher does download and places it in the
   chunk store too: the launcher sometimes receives a chunk in full but never
   finishes it and re-requests it every 90 s forever.
"""

import asyncio
import base64
import hashlib
import json
import logging
import os
import threading
import zlib
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPSConnection
from pathlib import Path

from mitmproxy import ctx, http

log = logging.getLogger("wollay")

API_HOST = "wollay.com"
PREFETCH_WORKERS = 8
MAX_CONSECUTIVE_FAILURES = 10
# Request headers not to copy from the launcher's requests.
SKIP_HEADERS = {"host", "content-length", "connection", "accept-encoding", "transfer-encoding"}


def b64url(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def inflate(body: bytes) -> bytes:
    try:
        return zlib.decompress(body, -15)  # deflate-raw
    except zlib.error:
        return zlib.decompress(body)


def store(chunks_dir: Path, chunk_id: str, data: bytes) -> bool:
    target = chunks_dir / chunk_id
    if target.exists():
        return False
    chunks_dir.mkdir(parents=True, exist_ok=True)
    tmp = chunks_dir / f".{chunk_id}.cwo-tmp"
    tmp.write_bytes(data)
    os.replace(tmp, target)
    return True


def api(method: str, path: str, headers: dict, body: bytes = b"") -> bytes:
    conn = HTTPSConnection(API_HOST, timeout=30)
    try:
        conn.request(method, path, body=body or None, headers=headers)
        r = conn.getresponse()
        data = r.read()
        if r.status != 200:
            raise RuntimeError(f"HTTP {r.status}")
        return data
    finally:
        conn.close()


class WollayAddon:
    def __init__(self):
        self.prefetch_task = None

    def load(self, loader):
        loader.add_option("cwo_data_dir", str, "", "com.wollay.launcher data dir")
        loader.add_option("cwo_chunk_rescue", bool, True, "write received chunks into the chunk store")
        loader.add_option("cwo_prefetch", bool, True, "download missing chunks before the launcher does")
        loader.add_option("cwo_prefetch_hold", int, 1800, "max. seconds to hold the update check while prefetching")

    async def request(self, flow: http.HTTPFlow):
        if flow.request.pretty_host != API_HOST or flow.request.path.split("?", 1)[0] != "/api/updates/check":
            return
        if not (ctx.options.cwo_prefetch and ctx.options.cwo_data_dir):
            return
        headers = {k: v for k, v in flow.request.headers.items() if k.lower() not in SKIP_HEADERS}
        if self.prefetch_task is None or self.prefetch_task.done():
            self.prefetch_task = asyncio.ensure_future(
                asyncio.to_thread(self.prefetch, flow.request.method, flow.request.path, headers, flow.request.content)
            )
        try:
            await asyncio.wait_for(asyncio.shield(self.prefetch_task), ctx.options.cwo_prefetch_hold)
        except asyncio.TimeoutError:
            log.warning("prefetch still running, letting the launcher's update check through")
        except Exception as e:
            log.warning(f"prefetch failed: {e!r}")

    def responseheaders(self, flow: http.HTTPFlow):
        path = flow.request.path.split("?", 1)[0]
        if not path.startswith("/api/updates/chunks/") or not ctx.options.cwo_chunk_rescue:
            flow.response.stream = True
            return
        received = []

        def stream(data: bytes) -> bytes:
            if data:
                received.append(data)
            elif flow.response.status_code == 200:  # end of body
                self.rescue_chunk(b"".join(received))
            return data

        flow.response.stream = stream

    def rescue_chunk(self, body: bytes):
        try:
            data = inflate(body)
        except zlib.error as e:
            log.warning(f"received chunk cannot be inflated ({e}), skipped")
            return
        chunk_id = hashlib.sha256(data).hexdigest()
        # Chunks are content-addressed, so writing them into every channel is safe.
        for chunks in Path(ctx.options.cwo_data_dir).glob("games/*/*/chunks"):
            if store(chunks, chunk_id, data):
                log.info(f"rescued chunk {chunk_id[:12]} ({len(data)} B) -> {chunks.parent.name}")

    def prefetch(self, method: str, path: str, headers: dict, body: bytes):
        outer = json.loads(api(method, path, headers, body))
        channel = json.loads(b64url(outer["channel"]["payload"]))
        manifest = json.loads(b64url(json.loads(outer["manifest"])["payload"]))
        release, chunks = manifest["release"], manifest["chunks"]
        chunks_dir = Path(ctx.options.cwo_data_dir) / "games" / manifest["product"] / channel["channel"] / "chunks"

        missing = [(cid, c) for cid, c in chunks.items() if not (chunks_dir / cid).exists()]
        if not missing:
            log.info(f"prefetch {release}: all {len(chunks)} chunks present")
            return
        size = sum(c["compressedSize"] for _, c in missing)
        log.info(f"prefetch {release}: downloading {len(missing)} of {len(chunks)} chunks ({size / 2**20:.0f} MiB)")
        # Chunks are authorized with the short-lived download token from the check response.
        chunk_headers = {"Authorization": f"Bearer {outer['downloadToken']}", "Accept": "*/*"}
        abort = threading.Event()

        def fetch(item) -> bool:
            cid, c = item
            err = None
            for _ in range(2):
                if abort.is_set():
                    return False
                try:
                    data = api("GET", f"/api/updates/chunks/{c['compressedSha256']}", chunk_headers)
                    if hashlib.sha256(data).hexdigest() != c["compressedSha256"]:
                        raise ValueError("compressed hash mismatch")
                    data = inflate(data)
                    if hashlib.sha256(data).hexdigest() != cid:
                        raise ValueError("chunk hash mismatch")
                    store(chunks_dir, cid, data)
                    return True
                except Exception as e:
                    err = e
            log.warning(f"prefetch chunk {cid[:12]} failed: {err}")
            return False

        if not fetch(missing[0]):  # probe once before going parallel
            log.warning(f"prefetch {release}: first chunk failed, leaving the download to the launcher")
            return
        done, failed, streak = 1, 0, 0
        with ThreadPoolExecutor(PREFETCH_WORKERS) as pool:
            for ok in pool.map(fetch, missing[1:]):
                done += ok
                failed += not ok
                streak = 0 if ok else streak + 1
                if streak >= MAX_CONSECUTIVE_FAILURES and not abort.is_set():
                    log.warning(f"prefetch {release}: {streak} failures in a row, giving up")
                    abort.set()
                if (done + failed) % 200 == 0:
                    log.info(f"prefetch {release}: {done + failed}/{len(missing)}")
        log.info(f"prefetch {release} finished: {done} ok, {failed} failed")


addons = [WollayAddon()]
