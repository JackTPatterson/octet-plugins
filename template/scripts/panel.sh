#!/bin/sh
# Panel: a row per TODO with an Open action, printed as JSON. Printing
# nothing hides the button.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
rows=''
count=0
tab=$(printf '\t')
# file:line:text as file<TAB>line<TAB>text (text may hold more colons).
todos 50 | awk -F: -v OFS="\t" '{ file = $1; line = $2; sub(/^[^:]*:[^:]*:/, ""); print file, line, $0 }' \
  > "${TMPDIR:-/tmp}/octet-todos.$$"
while IFS="$tab" read -r file line text; do
  count=$((count + 1))
  row=$(printf '{"id":%s,"title":%s,"detail":%s,"actions":[{"id":"open","title":"Open","symbol":"pencil"}]}' \
    "$(json "$file:$line")" "$(json "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-80)")" "$(json "$file:$line")")
  rows="${rows:+$rows,}$row"
done < "${TMPDIR:-/tmp}/octet-todos.$$"
rm -f "${TMPDIR:-/tmp}/octet-todos.$$"
[ "$count" -gt 0 ] || exit 0
printf '{"badge":"%s","rows":[%s],"actions":[{"id":"list","title":"List in a Tab"}]}\n' "$count" "$rows"
