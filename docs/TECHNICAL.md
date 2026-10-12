# Technical details

Tested on CachyOS (GNOME Wayland via XWayland, NVIDIA) with Proton Experimental and
GE-Proton 11-7, Wollay launcher 0.4.8, beta release `gh-38058447609-1-ff3bbe12`.

## Files

| File | Purpose |
| --- | --- |
| `install.sh` | Finds the setup in `~/Downloads`, installs dependencies, runs the setup silently (`/S`, it also installs WebView2) in a new prefix, sets up proxy CA and colour fix, creates the menu entry, starts the launcher. |
| `launch.sh` | Starts the proxy and the launcher; restarts the launcher if it crashes on start. Logs every start to `$CWO_HOME/logs/<date>/`. |
| `report.sh` | Bundles system details and the logs of the last 3 starts into one text file in the Downloads folder, with tokens, user ids, e-mail addresses and the home path removed. Also in the right-click menu of the app menu entry. |
| `scripts/sysinfo.sh` | System details for bug reports: distro, GPU/driver, desktop, scaling, mouse settings, Proton/launcher/game versions. |
| `scripts/install-deps.sh` | Uses system `umu-run`/`mitmdump` if present, otherwise downloads umu (zipapp) and installs mitmproxy with [uv](https://github.com/astral-sh/uv) into `~/.local/share/cubeworld-omega-linux`. No root needed. |
| `scripts/trust-proxy-ca.sh` | Creates the proxy CA and adds it to the prefix's `HKLM\…\SystemCertificates\Root`. |
| `proxy/wollay_addon.py` | mitmproxy addon: prefetch, streaming, chunk rescue. |
| `vkswapfix/` | Vulkan layer for the colour fix (source + prebuilt x86_64 library, needs glibc ≥ 2.14). |

Settings (environment variables): `CWO_HOME` (default `~/Games/CubeWorldOmega`), `PROTONPATH`
(default `GE-Proton`, stored in `$CWO_HOME/env` on first install), `CWO_PROXY=0` (no proxy),
`CWO_VK_SWAPFIX=0` (no colour fix), `CWO_DEBUG=0` (less logging, see below), `CWO_KEEP_LOGS`
(default 10).

Logs: one folder per start in `$CWO_HOME/logs/` (the newest 10 are kept) with `launcher.log`
(Wine/Proton output), `proxy.log`, `system.txt` and `client.log` (the game's own log, copied when
the launcher exits). `$CWO_HOME/launcher.log` and `proxy.log` point to the newest ones. During the
beta `CWO_DEBUG=1` is the default: Wine's error messages (Proton turns them off) and the colour
fix's messages are logged (`WINEDEBUG=+timestamp,+pid,fixme-all`, `CWO_VK_SWAPFIX_DEBUG=1`).

## Problems and workarounds

| Problem | Workaround |
| --- | --- |
| Downloads/updates stall mid-body. Wine's Schannel only does TLS 1.2; responses (update manifest, chunks) stop arriving and the launcher times out after 90 s. | `launch.sh` starts `mitmdump` on `127.0.0.1:8899` and sets `HTTPS_PROXY` (honoured by the launcher's reqwest client, not by WebView2). Only `wollay.com` and the Google services the launcher uses for sign-in and access checks (`firestore`, `identitytoolkit`, `securetoken` on googleapis.com) are intercepted, everything else is tunneled. The CA is trusted in the prefix only; it lives in `$CWO_HOME/mitmproxy` (mode 700). |
| Even through the proxy, the launcher stalls on large responses. | The proxy streams responses instead of buffering them; that is enough for the 1.6 MB manifest. |
| Chunk downloads still stall. | **Prefetch:** the launcher's `POST /api/updates/check` is held back while the addon sends the same request itself, reads the signed manifest and downloads all chunks missing from the launcher's content-addressed store (`games/<product>/<channel>/chunks/<sha256 of inflated data>`), authorized with the `downloadToken` from the check response and verified against `compressedSha256` and the chunk id. Then the launcher's request goes through and it finds everything locally. It probes one chunk first and stops after 10 failures in a row. Chunks the launcher downloads itself are also stored (it sometimes receives a chunk completely but never finishes it). |
| Red and blue swapped in game. The client creates its swapchain as `R8G8B8A8_UNORM`, which X11/XWayland surfaces (Mesa and NVIDIA) don't offer; the driver accepts it and X reads the pixels as BGRX. | Implicit Vulkan layer `VK_LAYER_CWO_swapchain_format`, only active with `CWO_VK_SWAPFIX=1`: if the surface doesn't list the requested RGBA format but lists BGRA, the swapchain and the image views of its images are created as `B8G8R8A8`. |
| Launcher crashes on start (page fault in `ole32!RevokeDragDrop`). wry's drag-and-drop setup revokes the drop targets of the WebView2 child windows, which belong to the `msedgewebview2.exe` process. Wine's `RevokeDragDrop`, unlike its `RegisterDragDrop`, doesn't check the window's process and releases the other process's `IDropTarget` pointer. It's a race, so it happens only sometimes (more often with GE-Proton). | `launch.sh` restarts it up to 10 times if it crashes within 60 s. Proper fix would be in Wine (`dlls/ole32/ole2.c`). |
| Launcher crashes on start due to Proton's accessibility helper (Xalia). | `PROTON_USE_XALIA=0` |
| WebView2 content is blank under Wine's native Wayland driver. | `PROTON_ENABLE_WAYLAND=0` (XWayland) |
| Launcher is tiny on HiDPI screens (Wine reports 96 DPI). | `install.sh --dpi 192` sets `LogPixels`. |
| Upstream Wine (not Proton) leaves the launcher blank (no DirectComposition). | Use Proton / GE-Proton (default). |
| The mouse cursor stays a resize arrow inside the launcher window (borderless window; the cursor of the WebView2 content, which belongs to another process, is not applied). | Not fixed. Doesn't affect clicking or the game. |
