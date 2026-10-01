#!/bin/sh
# What a panel action does: OCTET_ACTION is the action's id and OCTET_ITEM
# its row's id. A command printed here opens in a new tab.
case "$OCTET_ACTION" in
  open)
    file=${OCTET_ITEM%:*}
    line=${OCTET_ITEM##*:}
    echo "${EDITOR:-vi} +$line '$file'"
    echo "label: $(basename "$file")"
    ;;
  list)
    sh "$OCTET_PLUGIN_DIR/scripts/menu.sh"
    ;;
esac
