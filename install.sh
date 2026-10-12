#!/usr/bin/env bash
# Install the Wollay launcher (Cube World Omega) into its own Proton prefix,
# set up all workarounds and start it.
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$REPO/scripts/common.sh"

usage() {
    cat <<EOF
usage: $0 [Wollay-Launcher-x.y.z-Setup.exe] [--dpi N] [--no-start]

Without a path, the newest Wollay-Launcher-*-Setup.exe in your Downloads folder is used.

  --dpi N      Windows DPI for the prefix (96 = 100 %, 144 = 150 %, 192 = 200 %)
  --no-start   do not start the launcher at the end

Environment: CWO_HOME (default ~/Games/CubeWorldOmega), PROTONPATH (default GE-Proton)
EOF
    exit 1
}

SETUP="" DPI="" START=1
while [ $# -gt 0 ]; do
    case "$1" in
        --dpi) DPI="${2:?}"; shift ;;
        --no-start) START=0 ;;
        -h|--help) usage ;;
        *) SETUP="$1" ;;
    esac
    shift
done

if [ -z "$SETUP" ]; then
    DL="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
    SETUP="$(ls -t "$DL"/Wollay-Launcher-*Setup*.exe "$HOME"/Downloads/Wollay-Launcher-*Setup*.exe "$REPO"/Wollay-Launcher-*Setup*.exe 2>/dev/null | head -1 || true)"
    if [ -z "$SETUP" ]; then
        echo "The launcher setup (Wollay-Launcher-...-Setup.exe) was not found in $DL." >&2
        echo "Run this again with the path to the file, for example:" >&2
        echo "  $0 ~/Desktop/Wollay-Launcher-0.4.8-Setup.exe" >&2
        echo "Tip: type the command and a space, then drag the file into the terminal window." >&2
        exit 1
    fi
fi
[ -f "$SETUP" ] || die "file not found: $SETUP"
echo "==> Using $SETUP"

"$REPO/scripts/install-deps.sh"
find_umu

mkdir -p "$WINEPREFIX"
[ -f "$CWO_HOME/env" ] || printf 'PROTONPATH=%q\n' "$PROTONPATH" >"$CWO_HOME/env"

echo "==> Installing the launcher (the first time this also downloads Proton, please wait)"
# Tauri NSIS installer; /S = silent. It also installs the WebView2 runtime.
"${UMU[@]}" "$SETUP" /S >"$CWO_HOME/install.log" 2>&1 || true
[ -f "$CWO_LAUNCHER_EXE" ] || die "launcher installation failed, see $CWO_HOME/install.log"

if [ -n "$DPI" ]; then
    echo "==> Setting DPI to $DPI"
    printf 'Windows Registry Editor Version 5.00\r\n\r\n[HKEY_CURRENT_USER\\Control Panel\\Desktop]\r\n"LogPixels"=dword:%08x\r\n' "$DPI" \
        >"$WINEPREFIX/drive_c/cwo-dpi.reg"
    "${UMU[@]}" regedit /S 'C:\cwo-dpi.reg' >/dev/null 2>&1
    rm -f "$WINEPREFIX/drive_c/cwo-dpi.reg"
fi

echo "==> Setting up the download fix (local proxy)"
"$REPO/scripts/trust-proxy-ca.sh"

echo "==> Setting up the colour fix"
"$REPO/vkswapfix/build.sh"

echo "==> Creating menu entry"
ICON="$(find "$WINEPREFIX/drive_c/proton_shortcuts" -name '*wollay*.png' 2>/dev/null | sort | tail -1)"
mkdir -p "$HOME/.local/share/applications"
cat >"$HOME/.local/share/applications/cubeworld-omega.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cube World Omega
Comment=Wollay Launcher
Exec=env CWO_HOME="$CWO_HOME" "$REPO/launch.sh"
Icon=${ICON:-applications-games}
Categories=Game;
StartupWMClass=wollay-launcher.exe
EOF

echo
echo "Done! From now on, start the game with \"Cube World Omega\" in your app menu."
if [ $START = 1 ]; then
    echo "Starting the launcher now: log in, wait for the download, then press Play."
    setsid "$REPO/launch.sh" >/dev/null 2>&1 &
fi
