#!/usr/bin/env bash
# Print the system details that matter for bug reports (launch.sh saves them with every
# session, report.sh adds them to the report). report.sh removes personal data.
set -uo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
. "$REPO/scripts/common.sh"

has() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n' "$1"; }
# Strip colour codes, some tools print them even into files.
plain() { sed 's/\x1b\[[0-9;]*m//g'; }

section "Cube World Omega Linux"
echo "date: $(date -Is)"
echo "scripts: $(git -C "$REPO" describe --always --dirty 2>/dev/null || echo unknown)"
echo "CWO_HOME: $CWO_HOME"
grep -h '"DisplayVersion"' "$WINEPREFIX/user.reg" 2>/dev/null | head -1 | sed 's/^/launcher /'
for f in "$CWO_DATA_DIR"/games/*/*/installed.json; do
    [ -f "$f" ] && echo "game ($(basename "$(dirname "$f")")): $(grep -o '"channelRelease":"[^"]*"' "$f")"
done
[ -f "$CWO_DATA_DIR/settings.json" ] && { echo "launcher settings:"; cat "$CWO_DATA_DIR/settings.json"; echo; }
[ -f "$CWO_HOME/env" ] && { echo "env file:"; cat "$CWO_HOME/env"; }

section "System"
. /etc/os-release 2>/dev/null && echo "distro: ${PRETTY_NAME:-$ID}"
echo "kernel: $(uname -r)"
echo "cpu: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
awk '/MemTotal/ { printf "ram: %.1f GiB\n", $2 / 1048576 }' /proc/meminfo
echo "free space: $(df -h --output=avail "$CWO_HOME" 2>/dev/null | tail -1 | tr -d ' ')"
echo "ntsync: $([ -e /dev/ntsync ] && echo yes || echo no)"

section "Graphics"
has lspci && lspci | grep -iE 'vga|3d controller|display controller' | cut -d' ' -f2-
has nvidia-smi && echo "nvidia driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
has vulkaninfo && timeout 20 vulkaninfo --summary 2>/dev/null | grep -E '^\s*(deviceName|deviceType|driverName|driverInfo|apiVersion)\s*=' | sed 's/^\s*//'
ls "${XDG_DATA_HOME:-$HOME/.local/share}/vulkan/implicit_layer.d/VkLayer_CWO_swapchain_format.json" >/dev/null 2>&1 \
    && echo "colour fix layer: installed" || echo "colour fix layer: MISSING"

section "Desktop"
echo "session: ${XDG_SESSION_TYPE:-?}, desktop: ${XDG_CURRENT_DESKTOP:-?}, WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}, DISPLAY=${DISPLAY:-}"
grep -h '"LogPixels"' "$WINEPREFIX/user.reg" 2>/dev/null | sed 's/^/wine /'
if has gsettings; then
    for k in "org.gnome.desktop.interface scaling-factor" "org.gnome.desktop.interface text-scaling-factor" \
        "org.gnome.mutter experimental-features" "org.gnome.desktop.peripherals.mouse speed" \
        "org.gnome.desktop.peripherals.mouse accel-profile"; do
        v="$(gsettings get $k 2>/dev/null)" && echo "$k: $v"
    done
fi
f="${XDG_CONFIG_HOME:-$HOME/.config}/monitors.xml"
[ -f "$f" ] && grep -oE '<(connector|scale)>[^<]*' "$f" | sed 's/<//; s/>/: /' | paste -sd' ' | sed 's/^/gnome monitors: /'
has kscreen-doctor && timeout 10 kscreen-doctor -o 2>/dev/null | plain | grep -E 'Output:|Scale|Modes' | sed 's/Modes:.*\(\S*\*\)/current mode: \1/'
for f in "${XDG_CONFIG_HOME:-$HOME/.config}/kcminputrc"; do
    [ -f "$f" ] && grep -iE '^\[|accel|pointer' "$f" | grep -B1 -iE 'accel|pointer' | grep -v '^--'
done
has hyprctl && timeout 10 hyprctl monitors 2>/dev/null | grep -E '^Monitor|scale:|@'
has swaymsg && timeout 10 swaymsg -t get_outputs 2>/dev/null | grep -E '"(name|scale)"'
has xrandr && timeout 10 xrandr --current 2>/dev/null | grep -E ' connected|\*'
true
