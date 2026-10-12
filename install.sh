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

# Turn a dragged-and-dropped or typed path into a plain one ('...', "...", file://..., "\ ").
clean_path() {
    local p="$1"
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    case "$p" in \'*\') p="${p:1:${#p}-2}" ;; \"*\") p="${p:1:${#p}-2}" ;; esac
    case "$p" in file://*) p="$(printf '%b' "$(echo "${p#file://}" | sed 's/%/\\x/g')")" ;; esac
    case "$p" in *\\*) p="$(printf '%s' "$p" | sed 's/\\\(.\)/\1/g')" ;; esac
    case "$p" in "~/"*) p="$HOME/${p#\~/}" ;; esac
    printf '%s' "$p"
}

ask_setup() {
    echo
    echo "I could not find the launcher setup (Wollay-Launcher-...-Setup.exe) in your Downloads folder."
    if command -v zenity >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1; then
        echo "Please choose the file in the window that opens."
        if command -v kdialog >/dev/null 2>&1; then
            SETUP="$(kdialog --title "Choose Wollay-Launcher-...-Setup.exe" --getopenfilename "$HOME" "*.exe" 2>/dev/null || true)"
        else
            SETUP="$(zenity --file-selection --title="Choose Wollay-Launcher-...-Setup.exe" --file-filter="*.exe" 2>/dev/null || true)"
        fi
        [ -f "$SETUP" ] && return
    fi
    [ -t 0 ] || die "run again with the path to the setup file: $0 /path/to/Wollay-Launcher-...-Setup.exe"
    while true; do
        echo "Drag the file into this window (or type where it is) and press Enter:"
        read -r answer || exit 1
        SETUP="$(clean_path "$answer")"
        [ -n "$SETUP" ] || exit 1
        [ -f "$SETUP" ] && return
        echo "That file does not exist: $SETUP"
    done
}

if [ -z "$SETUP" ]; then
    DL="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
    SETUP="$(ls -t "$DL"/Wollay-Launcher-*Setup*.exe "$HOME"/Downloads/Wollay-Launcher-*Setup*.exe "$REPO"/Wollay-Launcher-*Setup*.exe 2>/dev/null | head -1 || true)"
    [ -n "$SETUP" ] || ask_setup
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
"$REPO/scripts/menu-entry.sh"

echo
echo "Done! From now on, start the game with \"Cube World Omega\" in your app menu."
if [ $START = 1 ]; then
    echo "Starting the launcher now: log in, wait for the download, then press Play."
    setsid "$REPO/launch.sh" >/dev/null 2>&1 &
fi
