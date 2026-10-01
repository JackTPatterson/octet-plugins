#!/bin/sh
# Status bar chip: "4 TODO", amber past 10, the first few on hover.
# Printing nothing hides the chip.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
count=$(todos 1000 | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || exit 0
echo "$count TODO"
[ "$count" -gt 10 ] && echo "tone: warning"
printf 'help: %s\n' "$(todos 6 | cut -c1-90 | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')"
