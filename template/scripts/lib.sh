#!/bin/sh
# Shared by the scripts: the TODO lines in the repository, as
# file:line:text, at most $1 of them.
pattern=${TODO_PATTERN:-TODO|FIXME}

todos() {
  git grep -n -I -E "($pattern)" -- . 2>/dev/null | head -n "${1:-200}"
}

# `text` as a JSON string.
json() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\t\n' '  ')"
}
