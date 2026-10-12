#!/usr/bin/env bash
# Create (or refresh) the "Cube World Omega" app menu entry. Run by install.sh and on
# every start, so updates via git pull reach the menu entry too.
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
. "$REPO/scripts/common.sh"

ICON="$(find "$WINEPREFIX/drive_c/proton_shortcuts" -name '*wollay*.png' 2>/dev/null | sort | tail -1)"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$DIR"
cat >"$DIR/cubeworld-omega.desktop.tmp" <<EOF
[Desktop Entry]
Type=Application
Name=Cube World Omega
Comment=Wollay Launcher
Exec=env CWO_HOME="$CWO_HOME" "$REPO/launch.sh"
Icon=${ICON:-applications-games}
Categories=Game;
StartupWMClass=wollay-launcher.exe
Actions=update;report;

[Desktop Action update]
Name=Update Linux fixes
Name[de]=Linux-Fixes aktualisieren
Exec=env CWO_HOME="$CWO_HOME" "$REPO/update.sh"

[Desktop Action report]
Name=Create bug report
Name[de]=Fehlerbericht erstellen
Exec=env CWO_HOME="$CWO_HOME" "$REPO/report.sh"
EOF
if cmp -s "$DIR/cubeworld-omega.desktop.tmp" "$DIR/cubeworld-omega.desktop"; then
    rm "$DIR/cubeworld-omega.desktop.tmp"
else
    mv "$DIR/cubeworld-omega.desktop.tmp" "$DIR/cubeworld-omega.desktop"
fi
