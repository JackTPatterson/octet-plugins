#!/bin/sh
# A tab or workspace right-click item: prints what Octet runs in a new tab
# of the workspace. `dashboard` opens the live view; `start` and `stop` do
# that to the whole project, then open it; `logs` follows every container.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
action=${1:-dashboard}
ENGINE=$(engine)
if [ -z "$ENGINE" ]; then
  echo "message: Neither Docker nor Podman is installed"
  exit 0
fi
if ! find_project; then
  echo "message: No Compose file or dev container here"
  exit 0
fi

name=$(basename "$PROJECT_DIR")
dashboard="sh $(quote "$OCTET_PLUGIN_DIR/scripts/dashboard.sh") $(quote "$PROJECT_DIR")"
if [ "$MODE" = compose ]; then
  compose="$ENGINE compose -f $(quote "$COMPOSE_FILE")"
else
  names=$(list_containers 2>/dev/null | cut -f1 | tr '\n' ' ')
  if [ -z "$names" ]; then
    echo "message: The dev container for $name hasn't been created yet"
    exit 0
  fi
fi

case "$action" in
  dashboard)
    echo "$dashboard"
    echo "label: $name · containers"
    ;;
  start)
    if [ "$MODE" = compose ]; then echo "$compose up -d && $dashboard"
    else echo "$ENGINE start $names && $dashboard"
    fi
    echo "label: $name · containers"
    ;;
  stop)
    if ! list_containers 2>/dev/null | cut -f3 | grep -qx running; then
      echo "message: Nothing is running for $name"
      exit 0
    fi
    if [ "$MODE" = compose ]; then echo "$compose stop && $dashboard"
    else echo "$ENGINE stop $names && $dashboard"
    fi
    echo "label: $name · containers"
    ;;
  logs)
    if [ "$MODE" = compose ]; then echo "$compose logs -f --tail 200"
    else echo "$ENGINE logs -f --tail 200 $(printf '%s' "$names" | cut -d' ' -f1)"
    fi
    echo "label: $name · logs"
    ;;
esac
echo "cwd: $PROJECT_DIR"
