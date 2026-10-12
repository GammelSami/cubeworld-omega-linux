#!/usr/bin/env bash
# Remove Cube World Omega, the launcher prefix and everything install.sh set up.
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$REPO/scripts/common.sh"

echo "This deletes $CWO_HOME (the game, the launcher and your launcher login)."
read -rp "Continue? [y/N] " ok
[ "$ok" = y ] || [ "$ok" = Y ] || exit 1

rm -rf "$CWO_HOME" "$CWO_TOOLS" \
    "$HOME/.local/share/applications/cubeworld-omega.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/vulkan/implicit_layer.d/VkLayer_CWO_swapchain_format.json"
echo "Done. You can now delete this folder: $REPO"
