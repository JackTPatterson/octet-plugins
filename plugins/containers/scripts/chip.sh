#!/bin/sh
# How many of this project's containers are up: green when all are, amber
# when one has failed or is unhealthy. Each container's state on hover; a
# click opens the first port one publishes.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
ENGINE=$(engine)
[ -n "$ENGINE" ] || exit 0
find_project || exit 0

if ! rows=$(list_containers 2>/dev/null); then
  echo "$ENGINE not running"
  echo "tone: muted"
  echo "help: Start $ENGINE to see this project's containers"
  exit 0
fi
[ -n "$rows" ] || exit 0

tab=$(printf '\t')
total=0 running=0 failing=0 help='' url=''
while IFS="$tab" read -r _ service state status ports; do
  total=$((total + 1))
  [ "$state" = running ] && running=$((running + 1))
  case "$status" in
    *unhealthy*) failing=$((failing + 1)) ;;
    "Exited (0)"*|"Exited (137)"*|"Exited (143)"*) ;;
    Exited*|Restarting*) failing=$((failing + 1)) ;;
  esac
  port=$(first_port "$ports")
  [ -z "$url" ] && [ -n "$port" ] && [ "$state" = running ] && url="http://localhost:$port"
  line="$service: ${status:-$state}${port:+ · :$port}"
  help="${help:+$help\\n}$line"
done <<ROWS
$rows
ROWS

if [ "$running" -eq 0 ]; then
  echo "stopped"
  echo "tone: muted"
elif [ "$running" -eq "$total" ] && [ "$failing" -eq 0 ]; then
  echo "$running up"
  echo "tone: success"
else
  echo "$running/$total up"
  [ "$failing" -gt 0 ] && echo "tone: warning"
fi
printf 'help: %s\n' "$help"
[ -n "$url" ] && echo "url: $url"
exit 0
