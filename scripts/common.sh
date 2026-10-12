# Shared settings for install.sh / launch.sh. Sourced, not executed.

CWO_HOME="${CWO_HOME:-$HOME/Games/CubeWorldOmega}"
# Per-install overrides (written by install.sh), e.g. PROTONPATH.
[ -f "$CWO_HOME/env" ] && . "$CWO_HOME/env"

export WINEPREFIX="$CWO_HOME/pfx"
export GAMEID="${GAMEID:-umu-cubeworld-omega}"
# umu downloads the latest GE-Proton automatically when set to "GE-Proton".
export PROTONPATH="${PROTONPATH:-GE-Proton}"
# Xalia (Proton's accessibility helper) crashes the launcher on start.
export PROTON_USE_XALIA=0
# WebView2 content stays blank under Wine's native Wayland driver; use XWayland.
export PROTON_ENABLE_WAYLAND=0
# Enables VK_LAYER_CWO_swapchain_format (vkswapfix/) if installed: fixes swapped red/blue.
export CWO_VK_SWAPFIX="${CWO_VK_SWAPFIX:-1}"

# Extra logging, on by default during the beta. Turn off with CWO_DEBUG=0 in $CWO_HOME/env.
CWO_DEBUG="${CWO_DEBUG:-1}"
CWO_LOGS="$CWO_HOME/logs"
CWO_KEEP_LOGS="${CWO_KEEP_LOGS:-10}"

CWO_PROXY_PORT="${CWO_PROXY_PORT:-8899}"
CWO_MITM_DIR="$CWO_HOME/mitmproxy"
CWO_LOCALAPPDATA="$WINEPREFIX/drive_c/users/steamuser/AppData/Local"
CWO_LAUNCHER_EXE="$CWO_LOCALAPPDATA/Wollay Launcher/wollay-launcher.exe"
CWO_DATA_DIR="$CWO_LOCALAPPDATA/com.wollay.launcher"
# Tools we download ourselves if the system doesn't have them (umu, uv, mitmproxy).
CWO_TOOLS="${CWO_TOOLS:-${XDG_DATA_HOME:-$HOME/.local/share}/cubeworld-omega-linux}"

die() { echo "error: $*" >&2; exit 1; }
# Desktop notification, for scripts started from the app menu.
notify() { notify-send "Cube World Omega" "$*" >/dev/null 2>&1 || true; }

# Sets UMU (array) to a working umu-run command.
find_umu() {
    if [ -z "${CWO_OWN_DEPS:-}" ] && command -v umu-run >/dev/null 2>&1; then
        UMU=(umu-run)
    elif [ -f "$CWO_TOOLS/umu/umu-run" ]; then
        if command -v python3 >/dev/null 2>&1; then
            UMU=(python3 "$CWO_TOOLS/umu/umu-run")
        else
            UMU=("$CWO_TOOLS/venv/bin/python" "$CWO_TOOLS/umu/umu-run")
        fi
    else
        return 1
    fi
}

# Sets MITMDUMP to a working mitmdump.
find_mitmdump() {
    if [ -x "$CWO_TOOLS/venv/bin/mitmdump" ]; then
        MITMDUMP="$CWO_TOOLS/venv/bin/mitmdump"
    elif [ -z "${CWO_OWN_DEPS:-}" ] && command -v mitmdump >/dev/null 2>&1; then
        MITMDUMP="$(command -v mitmdump)"
    else
        return 1
    fi
}
