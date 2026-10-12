#!/usr/bin/env bash
# Update these scripts (git pull) and apply what changed. Also in the right-click
# menu of the app menu entry.
set -uo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$REPO/scripts/common.sh"

fail() {
    echo "Update failed: $*"
    notify "Update failed: $*"
    exit 1
}

old=$(git -C "$REPO" rev-parse HEAD 2>/dev/null) || fail "git not found or $REPO is not a git folder"
git -C "$REPO" pull --ff-only || fail "git pull did not work, run it in a terminal to see why: git -C $REPO pull"
new=$(git -C "$REPO" rev-parse HEAD)

if [ "$old" = "$new" ]; then
    echo "Already up to date."
    notify "Already up to date."
    exit 0
fi
"$REPO/scripts/menu-entry.sh" || true
git -C "$REPO" diff --quiet "$old" "$new" -- vkswapfix || "$REPO/vkswapfix/build.sh"
echo "Updated. Changes:"
git -C "$REPO" log --format='  %s' "$old..$new"
notify "Updated: $(git -C "$REPO" log --format='%s' "$old..$new" | head -3 | paste -sd ';')"
