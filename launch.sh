#!/usr/bin/env bash
# Start the Wollay launcher in its Proton prefix, behind the local TLS proxy.
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$REPO/scripts/common.sh"

find_umu || die "umu-run not found, run install.sh first"
[ -f "$CWO_LAUNCHER_EXE" ] || die "launcher not installed in $WINEPREFIX, run install.sh first"

if [ "${CWO_PROXY:-1}" = 1 ]; then
    find_mitmdump || die "mitmdump not found, run install.sh first (or start with CWO_PROXY=0)"
    [ -f "$CWO_MITM_DIR/mitmproxy-ca-cert.pem" ] || die "proxy CA missing, run install.sh first"
    "$MITMDUMP" --listen-host 127.0.0.1 --listen-port "$CWO_PROXY_PORT" \
        --set confdir="$CWO_MITM_DIR" \
        --allow-hosts '(^|\.)wollay\.com(:443)?$' \
        --allow-hosts '^(firestore|identitytoolkit|securetoken)\.googleapis\.com(:443)?$' \
        --set cwo_data_dir="$CWO_DATA_DIR" \
        -s "$REPO/proxy/wollay_addon.py" \
        ${CWO_PROXY_OPTS:-} \
        >"$CWO_HOME/proxy.log" 2>&1 &
    PROXY_PID=$!
    trap 'kill $PROXY_PID 2>/dev/null || true' EXIT
    for _ in $(seq 50); do
        (exec 3<>"/dev/tcp/127.0.0.1/$CWO_PROXY_PORT") 2>/dev/null && break
        kill -0 $PROXY_PID 2>/dev/null || die "proxy failed to start, see $CWO_HOME/proxy.log"
        sleep 0.2
    done
    # Only the launcher's own HTTP client (reqwest) honours these; WebView2 does not.
    export HTTPS_PROXY="http://127.0.0.1:$CWO_PROXY_PORT" HTTP_PROXY="http://127.0.0.1:$CWO_PROXY_PORT"
    export NO_PROXY="localhost,127.0.0.1,ipc.localhost"
fi

LOG="$CWO_HOME/launcher.log"
: >"$LOG"
for attempt in $(seq 10); do
    start=$SECONDS
    logpos=$(stat -c %s "$LOG")
    "${UMU[@]}" "$CWO_LAUNCHER_EXE" "$@" >>"$LOG" 2>&1 || true
    # The launcher sometimes crashes right at start: its drag-and-drop setup calls
    # RevokeDragDrop on WebView2 windows owned by another process, and Wine's
    # ole32 then releases a pointer from that process. Starting it again helps.
    if [ $((SECONDS - start)) -lt 60 ] && tail -c +$((logpos + 1)) "$LOG" | grep -qE 'Unhandled (exception: )?page fault'; then
        echo "== launcher crashed on start, retrying ($attempt) ==" >>"$LOG"
        continue
    fi
    break
done
