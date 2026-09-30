#!/bin/sh
# Does what was clicked in the Containers panel: OCTET_ACTION says what,
# OCTET_ITEM which service (Compose) or container (dev container), else all
# of them. Quick ones run here; logs, a shell and the dashboard print a
# command, which Octet opens in a new tab.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
ENGINE=$(engine)
[ -n "$ENGINE" ] || { echo "message: Neither Docker nor Podman is installed"; exit 0; }
find_project || { echo "message: No Compose file or dev container here"; exit 0; }
item=${OCTET_ITEM:-}
name=$(basename "$PROJECT_DIR")

compose() { (cd "$PROJECT_DIR" && $ENGINE compose -f "$COMPOSE_FILE" "$@"); }
all() { list_containers 2>/dev/null | cut -f1 | grep -v '^-$'; }

# Runs a command, and says why when it fails.
quietly() {
  if ! out=$("$@" 2>&1); then
    echo "message: $(printf '%s\n' "$out" | grep -v '^ *$' | tail -n 1)"
  fi
}

shell_command='sh -c '"'"'command -v bash >/dev/null && exec bash || exec sh'"'"

case "$OCTET_ACTION" in
  up|stop|restart)
    if [ "$MODE" = compose ]; then
      if [ "$OCTET_ACTION" = up ]; then set -- up -d; else set -- "$OCTET_ACTION"; fi
      if [ -n "$item" ]; then quietly compose "$@" "$item"; else quietly compose "$@"; fi
    else
      verb=$OCTET_ACTION; [ "$verb" = up ] && verb=start
      # shellcheck disable=SC2046 # One argument per container.
      if [ -n "$item" ]; then quietly $ENGINE "$verb" "$item"; else quietly $ENGINE "$verb" $(all); fi
    fi ;;
  down)
    # shellcheck disable=SC2046 # One argument per container.
    if [ "$MODE" = compose ]; then quietly compose down; else quietly $ENGINE stop $(all); fi ;;
  logs)
    if [ "$MODE" = compose ]; then
      echo "$ENGINE compose -f $(quote "$COMPOSE_FILE") logs -f --tail 200${item:+ $(quote "$item")}"
    else
      echo "$ENGINE logs -f --tail 200 $(quote "${item:-$(all | head -n 1)}")"
    fi
    echo "label: ${item:-$name} · logs"
    echo "cwd: $PROJECT_DIR" ;;
  shell)
    if [ "$MODE" = compose ]; then
      echo "$ENGINE compose -f $(quote "$COMPOSE_FILE") exec $(quote "$item") $shell_command"
    else
      echo "$ENGINE exec -it $(quote "$item") $shell_command"
    fi
    echo "label: $item · shell"
    echo "cwd: $PROJECT_DIR" ;;
  dashboard)
    echo "sh $(quote "$OCTET_PLUGIN_DIR/scripts/dashboard.sh") $(quote "$PROJECT_DIR")"
    echo "label: $name · containers"
    echo "cwd: $PROJECT_DIR" ;;
esac
