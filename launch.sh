#!/usr/bin/env bash
# Start the Wollay launcher in its Proton prefix, behind the local TLS proxy.
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$REPO/scripts/common.sh"

find_umu || die "umu-run not found, run install.sh first"
[ -f "$CWO_LAUNCHER_EXE" ] || die "launcher not installed in $WINEPREFIX, run install.sh first"

# A second start would wait for the running launcher to exit and then open it again.
if pgrep -f 'wollay-launcher\.exe' >/dev/null; then
    echo "The launcher is already running."
    notify "The launcher is already running."
    exit 0
fi

# Refresh the menu entry if it belongs to this copy of the scripts.
grep -qF "$REPO/launch.sh" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/cubeworld-omega.desktop" 2>/dev/null &&
    { "$REPO/scripts/menu-entry.sh" || true; }

# Every start gets its own log folder; report.sh bundles the newest ones.
SESSION="$CWO_LOGS/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$SESSION"
ls -1d "$CWO_LOGS"/20*/ | sort -r | tail -n +$((CWO_KEEP_LOGS + 1)) | xargs -r -d '\n' rm -rf
ln -sfn "$SESSION/launcher.log" "$CWO_HOME/launcher.log"
ln -sfn "$SESSION/proxy.log" "$CWO_HOME/proxy.log"
"$REPO/scripts/sysinfo.sh" >"$SESSION/system.txt" 2>&1 &
CLIENT_LOG="$CWO_DATA_DIR/logs/client-latest.log"
cleanup() {
    [ -n "${PROXY_PID:-}" ] && kill "$PROXY_PID" 2>/dev/null
    # The game writes its own log; keep a copy if it ran during this session.
    [ "$CLIENT_LOG" -nt "$SESSION" ] && cp "$CLIENT_LOG" "$SESSION/client.log"
    true
}
trap cleanup EXIT

# Don't set WINEDEBUG here: with Wine's error messages on, the game's sign-in
# through the launcher failed ("GAME SIGN-IN FAILED. CHECK THE LAUNCHER.").
[ "$CWO_DEBUG" = 1 ] && export CWO_VK_SWAPFIX_DEBUG=1

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
        >"$SESSION/proxy.log" 2>&1 &
    PROXY_PID=$!
    for _ in $(seq 50); do
        (exec 3<>"/dev/tcp/127.0.0.1/$CWO_PROXY_PORT") 2>/dev/null && break
        kill -0 $PROXY_PID 2>/dev/null || die "proxy failed to start, see $SESSION/proxy.log"
        sleep 0.2
    done
    # Only the launcher's own HTTP client (reqwest) honours these; WebView2 does not.
    export HTTPS_PROXY="http://127.0.0.1:$CWO_PROXY_PORT" HTTP_PROXY="http://127.0.0.1:$CWO_PROXY_PORT"
    export NO_PROXY="localhost,127.0.0.1,ipc.localhost"
fi

LOG="$SESSION/launcher.log"
: >"$LOG"
for attempt in $(seq 10); do
    start=$SECONDS
    logpos=$(stat -c %s "$LOG")
    echo "== $(date +%T) starting launcher (attempt $attempt) ==" >>"$LOG"
    status=0
    "${UMU[@]}" "$CWO_LAUNCHER_EXE" "$@" >>"$LOG" 2>&1 || status=$?
    echo "== $(date +%T) launcher exited with status $status after $((SECONDS - start)) s ==" >>"$LOG"
    # The launcher sometimes crashes right at start: its drag-and-drop setup calls
    # RevokeDragDrop on WebView2 windows owned by another process, and Wine's
    # ole32 then releases a pointer from that process. Starting it again helps.
    if [ $((SECONDS - start)) -lt 60 ] && tail -c +$((logpos + 1)) "$LOG" | grep -qE 'Unhandled (exception: )?page fault'; then
        echo "== launcher crashed on start, retrying ($attempt) ==" >>"$LOG"
        continue
    fi
    break
done
