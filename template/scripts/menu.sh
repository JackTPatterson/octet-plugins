#!/bin/sh
# Right-click item: prints a command for a new tab, or a message.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
pattern=${TODO_PATTERN:-TODO|FIXME}
if [ -z "$(todos 1)" ]; then
  echo "message: No TODOs here"
  exit 0
fi
echo "git grep -n -E '(${pattern})' | less -R"
echo "label: TODOs"
