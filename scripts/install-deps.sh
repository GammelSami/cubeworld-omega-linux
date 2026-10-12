#!/usr/bin/env bash
# Make sure umu-run and mitmdump are available. Uses the system ones if present,
# otherwise downloads them into $CWO_TOOLS (no root needed).
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
. "$REPO/scripts/common.sh"

fetch() { # url out
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --progress-bar -o "$2" "$1"
    else
        wget -q --show-progress -O "$2" "$1"
    fi
}

latest_tag() { # owner/repo
    local url
    if command -v curl >/dev/null 2>&1; then
        url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")"
    else
        url="$(wget -S --spider "https://github.com/$1/releases/latest" 2>&1 | sed -n 's/^ *Location: //p' | tail -1)"
    fi
    echo "${url##*/}"
}

command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || die "need curl or wget"
mkdir -p "$CWO_TOOLS"

if ! find_mitmdump; then
    echo "==> Installing mitmproxy into $CWO_TOOLS"
    UV="$(command -v uv || true)"
    if [ -z "$UV" ]; then
        UV="$CWO_TOOLS/bin/uv"
        if [ ! -x "$UV" ]; then
            mkdir -p "$CWO_TOOLS/bin"
            fetch "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz" "$CWO_TOOLS/uv.tar.gz"
            tar -xzf "$CWO_TOOLS/uv.tar.gz" -C "$CWO_TOOLS/bin" --strip-components=1
            rm -f "$CWO_TOOLS/uv.tar.gz"
        fi
    fi
    export UV_PYTHON_INSTALL_DIR="$CWO_TOOLS/python"
    "$UV" venv --quiet --python 3.13 "$CWO_TOOLS/venv"
    "$UV" pip install --quiet --python "$CWO_TOOLS/venv/bin/python" mitmproxy
    find_mitmdump || die "mitmproxy installation failed"
fi

if ! find_umu; then
    echo "==> Installing umu-launcher into $CWO_TOOLS"
    tag="$(latest_tag Open-Wine-Components/umu-launcher)"
    [ -n "$tag" ] || die "could not determine latest umu-launcher release"
    fetch "https://github.com/Open-Wine-Components/umu-launcher/releases/download/$tag/umu-launcher-$tag-zipapp.tar" "$CWO_TOOLS/umu.tar"
    rm -rf "$CWO_TOOLS/umu"
    tar -xf "$CWO_TOOLS/umu.tar" -C "$CWO_TOOLS"
    rm -f "$CWO_TOOLS/umu.tar"
    find_umu || die "umu-launcher installation failed"
fi
