#!/bin/sh
# Completion for `todo open <file>`: files with TODOs, with how many each has.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
todos 1000 | cut -d: -f1 | sort | uniq -c | sort -rn | head -n 50 \
  | awk '{ printf "%s\t%s\t%d TODO\n", $2, $2, $1 }'
