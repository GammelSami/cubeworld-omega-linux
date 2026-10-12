#!/usr/bin/env bash
# Collect the logs of the last launcher sessions and system details into one text
# file in the Downloads folder, without login data, for a GitHub issue.
set -uo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$REPO/scripts/common.sh"

SESSIONS=3       # newest sessions to include
MAX_LINES=3000   # per log file (the end of it)

DL="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
[ -d "$DL" ] || DL="$HOME"
OUT="$DL/cubeworld-omega-report-$(date +%Y-%m-%d_%H-%M-%S).txt"

# Remove login data and personal paths. Logs don't contain passwords, but URLs and
# JSON can carry tokens, user ids or e-mail addresses.
redact() {
    local home
    home="$(printf '%s' "$HOME" | sed 's/[][\.*^$#]/\\&/g')"
    sed -E \
        -e "s#$home#~#g" \
        -e 's/(Bearer|Basic) [A-Za-z0-9._~+\/=-]+/\1 <redacted>/g' \
        -e 's/eyJ[A-Za-z0-9_-]{8,}(\.[A-Za-z0-9_-]+){1,2}/<token>/g' \
        -e 's/([?&#](key|code|state|token|code_challenge|redirect_uri|id_token|access_token|refresh_token)=)[^&" ]+/\1<redacted>/g' \
        -e 's/("(idToken|refreshToken|accessToken|access_token|refresh_token|id_token|token|customToken|downloadToken|email|localId|uid|userId|displayName|username|code)" *: *")[^"]*/\1<redacted>/g' \
        -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email>/g' \
        -e 's#(/documents/[^/ ?]+/)[^/ ?]+#\1<id>#g' \
        -e 's/(wollay-game-)[0-9a-f]+/\1<id>/g'
}

add_file() {
    local title="$1" file="$2"
    printf '\n\n======== %s ========\n' "$title"
    if [ ! -s "$file" ]; then
        echo "(missing or empty)"
        return
    fi
    local lines
    lines=$(wc -l <"$file")
    [ "$lines" -gt $MAX_LINES ] && echo "(last $MAX_LINES of $lines lines)"
    tail -n $MAX_LINES "$file"
}

{
    echo "Cube World Omega on Linux: bug report"
    echo "Personal data (login tokens, e-mail addresses, home folder path) has been removed."
    printf '\n======== system (now) ========\n'
    "$REPO/scripts/sysinfo.sh" 2>&1

    sessions=$(ls -1d "$CWO_HOME"/logs/20*/ 2>/dev/null | sort -r)
    printf '\n\n======== sessions ========\n'
    for s in $sessions; do
        crashes=$(grep -c 'launcher crashed on start' "$s/launcher.log" 2>/dev/null)
        echo "$(basename "$s"): start crashes: ${crashes:-0}, game started: $([ -f "$s/client.log" ] && echo yes || echo no)"
    done
    [ -n "$sessions" ] || echo "(none yet)"

    for s in $(echo "$sessions" | head -n $SESSIONS); do
        name=$(basename "$s")
        add_file "$name: system" "$s/system.txt"
        add_file "$name: launcher (Wine/Proton output)" "$s/launcher.log"
        add_file "$name: game (client-latest.log)" "$s/client.log"
        add_file "$name: proxy" "$s/proxy.log"
    done
    # Logs from before per-session logging, and a game log no session has picked up yet.
    [ -z "$sessions" ] && add_file "launcher.log" "$CWO_HOME/launcher.log" && add_file "proxy.log" "$CWO_HOME/proxy.log"
    newest=$(echo "$sessions" | head -n 1)
    cmp -s "$CWO_DATA_DIR/logs/client-latest.log" "${newest}client.log" ||
        add_file "game (current client-latest.log)" "$CWO_DATA_DIR/logs/client-latest.log"
    add_file "install.log" "$CWO_HOME/install.log"
} 2>&1 | redact >"$OUT"

echo "Bug report saved: $OUT"
echo "Please attach it to an issue: https://github.com/GammelSami/cubeworld-omega-linux/issues"
# Started from the app menu: show the file.
if [ ! -t 1 ]; then
    notify "Bug report saved in $(basename "$DL"): $(basename "$OUT")"
    xdg-open "$DL" >/dev/null 2>&1 &
fi
