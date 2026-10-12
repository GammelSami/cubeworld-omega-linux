#!/usr/bin/env bash
# Install the swapchain format layer as an implicit layer that is only active
# when CWO_VK_SWAPFIX=1 (set by launch.sh). Builds it from swapfix.c if a C
# compiler and the Vulkan headers are available (set VULKAN_INCLUDE to use
# headers from elsewhere), otherwise uses the prebuilt library.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
LIBDIR="${XDG_DATA_HOME:-$HOME/.local/share}/cubeworld-omega-linux"
LAYERDIR="${XDG_DATA_HOME:-$HOME/.local/share}/vulkan/implicit_layer.d"
LIB="$LIBDIR/libVkLayer_CWO_swapchain_format.so"
mkdir -p "$LIBDIR" "$LAYERDIR"
if ${CC:-cc} -O2 -Wall -Wextra -shared -fPIC -fvisibility=hidden ${VULKAN_INCLUDE:+-I"$VULKAN_INCLUDE"} \
    -o "$LIB.tmp" swapfix.c -lpthread 2>/dev/null; then
    mv "$LIB.tmp" "$LIB"
    echo "Built $LIB"
else
    rm -f "$LIB.tmp"
    cp prebuilt/libVkLayer_CWO_swapchain_format.so "$LIB"
    echo "Installed prebuilt $LIB"
fi
sed "s|@LIB@|$LIB|" VkLayer_CWO_swapchain_format.json.in >"$LAYERDIR/VkLayer_CWO_swapchain_format.json"
