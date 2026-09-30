#!/bin/sh
# The Containers button at the right of the tab bar: its badge, and a row
# per container with what can be done to it, printed as JSON for Octet.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
ENGINE=$(engine)
[ -n "$ENGINE" ] || exit 0
find_project || exit 0

if ! rows=$(list_containers 2>/dev/null); then
  printf '{"badge":"off","tone":"muted","message":%s}\n' "$(json "$ENGINE isn't running. Start it to see this project's containers.")"
  exit 0
fi

tab=$(printf '\t')
total=0 running=0 created=0 failing=0 items=''
while IFS="$tab" read -r name service state status ports; do
  [ -n "$service" ] || continue
  total=$((total + 1))
  case "$status" in
    *unhealthy*) tone=danger; failing=$((failing + 1)) ;;
    "Exited (0)"*|"Exited (137)"*|"Exited (143)"*) tone=muted ;;
    Exited*|Restarting*|Dead*) tone=danger; failing=$((failing + 1)) ;;
    *) case "$state" in running) tone=success ;; paused|restarting) tone=warning ;; *) tone=muted ;; esac ;;
  esac
  [ "$state" = "not created" ] || created=$((created + 1))
  port=$(first_port "$ports")
  detail=${status:-$state}
  [ -n "$port" ] && detail="$detail · :$port"
  url=''
  [ "$state" = running ] && [ -n "$port" ] && url="http://localhost:$port"
  # Compose acts on services, a dev container on its container.
  if [ "$MODE" = compose ]; then id=$service; else id=$name; fi
  if [ "$state" = running ]; then
    running=$((running + 1))
    actions='{"id":"restart","title":"Restart","symbol":"arrow.clockwise"},{"id":"stop","title":"Stop","symbol":"stop.fill"},{"id":"logs","title":"Logs","symbol":"doc.text"},{"id":"shell","title":"Shell","symbol":"terminal"}'
  elif [ "$state" = "not created" ]; then
    actions='{"id":"up","title":"Start","symbol":"play.fill"}'
  else
    actions='{"id":"up","title":"Start","symbol":"play.fill"},{"id":"logs","title":"Logs","symbol":"doc.text"}'
  fi
  item=$(printf '{"id":%s,"title":%s,"detail":%s,"tone":"%s"%s,"actions":[%s]}' \
    "$(json "$id")" "$(json "$service")" "$(json "$detail")" "$tone" "${url:+,\"url\":$(json "$url")}" "$actions")
  items="${items:+$items,}$item"
done <<ROWS
$rows
ROWS

if [ "$total" -eq 0 ]; then badge=''; tone=muted
elif [ "$running" -eq 0 ]; then badge=stopped; tone=muted
elif [ "$running" -eq "$total" ] && [ "$failing" -eq 0 ]; then badge="$running up"; tone=success
else badge="$running/$total"; if [ "$failing" -gt 0 ]; then tone=warning; else tone=normal; fi
fi

actions='{"id":"up","title":"Start All"}'
[ "$running" -gt 0 ] && actions="$actions"',{"id":"stop","title":"Stop All"}'
[ "$created" -gt 0 ] && actions="$actions"',{"id":"logs","title":"Logs"}'
actions="$actions"',{"id":"dashboard","title":"Dashboard"}'
if [ "$MODE" = compose ] && [ "$created" -gt 0 ]; then
  actions="$actions"',{"id":"down","title":"Down","confirm":"Stop and remove this project'"'"'s containers? Volumes stay."}'
fi

printf '{"badge":%s,"tone":"%s","message":%s,"rows":[%s],"actions":[%s]}\n' \
  "$(json "$badge")" "$tone" "$(json "No containers yet. Start them to see them here.")" "$items" "$actions"
