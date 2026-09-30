#!/bin/sh
# A live view of one project's containers: state, health, ports, CPU and
# memory, redrawn every few seconds, with keys to start, stop, restart,
# follow logs and open a shell. Usage: dashboard.sh PROJECT_FOLDER
OCTET_CWD=${1:-$PWD} OCTET_REPO_ROOT=${1:-$PWD}
here=$(dirname "$0")
. "$here/lib.sh"
ENGINE=$(engine)
[ -n "$ENGINE" ] || { echo "Neither Docker nor Podman is installed."; exit 1; }
find_project || { echo "No Compose file or dev container in $OCTET_CWD."; exit 1; }

esc=$(printf '\033')
bold="${esc}[1m" dim="${esc}[2m" red="${esc}[31m" green="${esc}[32m" yellow="${esc}[33m" reset="${esc}[0m"
tab=$(printf '\t')
saved=$(stty -g 2>/dev/null)
following=

restore() { [ -n "$saved" ] && stty "$saved" 2>/dev/null; printf '%s[?25h' "$esc"; }
quit() { restore; printf '\n'; exit 0; }
# Ctrl-C ends a log or a shell and comes back here; anywhere else it quits.
interrupted() { [ -n "$following" ] || quit; }
trap interrupted INT
trap quit TERM HUP

compose() { (cd "$PROJECT_DIR" && $ENGINE compose -f "$COMPOSE_FILE" "$@"); }

# The row numbered $1: sets NAME and SERVICE, or fails.
row() {
  line=$(printf '%s\n' "$rows" | sed -n "${1}p")
  [ -n "$line" ] || return 1
  NAME=$(printf '%s' "$line" | cut -f1)
  SERVICE=$(printf '%s' "$line" | cut -f2)
}

draw() {
  rows=$(list_containers 2>&1) || { failed=$rows; rows=; }
  running=$(printf '%s\n' "$rows" | awk -F'\t' '$3 == "running" { print $1 }')
  usage=
  if [ -n "$running" ]; then
    # shellcheck disable=SC2086 # One argument per container.
    usage=$($ENGINE stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' $running 2>/dev/null)
  fi

  printf '%s[H%s[2J' "$esc" "$esc"
  if [ "$MODE" = compose ]; then where="$COMPOSE_FILE"; else where="dev container"; fi
  printf '%s%s%s  %s%s · %s · %s%s\n\n' "$bold" "$(basename "$PROJECT_DIR")" "$reset" "$dim" "$where" "$ENGINE" "$(date +%H:%M:%S)" "$reset"
  if [ -n "${failed:-}" ]; then
    printf '%s%s isn'"'"'t answering:%s %s\n' "$red" "$ENGINE" "$reset" "$(printf '%s' "$failed" | head -n 1)"
    failed=
  elif [ -z "$rows" ]; then
    printf '%sNo containers yet. Press u to start them.%s\n' "$dim" "$reset"
  else
    printf '%s   %-22s %-12s %-26s %-8s %-20s %s%s\n' "$dim" SERVICE STATE STATUS CPU MEMORY PORTS "$reset"
    number=0
    while IFS="$tab" read -r name service state status ports; do
      number=$((number + 1))
      case "$status" in
        *unhealthy*) color=$red ;;
        "Exited (0)"*|"Exited (137)"*|"Exited (143)"*) color=$dim ;;
        Exited*|Restarting*|Dead*) color=$red ;;
        *) case "$state" in running) color=$green ;; paused|restarting) color=$yellow ;; *) color=$dim ;; esac ;;
      esac
      stats=$(printf '%s\n' "$usage" | awk -F'\t' -v n="$name" '$1 == n { print $2 "\t" $3 }')
      cpu=$(printf '%s' "$stats" | cut -f1)
      memory=$(printf '%s' "$stats" | cut -f2 | sed 's| / .*||')
      ports=$(printf '%s' "$ports" | tr ',' '\n' | sed -n 's/^ *[^>]*:\([0-9][0-9]*\)->.*/:\1/p' | sort -u | tr '\n' ' ')
      printf '%2d %-22.22s %s%-12.12s%s %-26.26s %-8s %-20.20s %s\n' "$number" "$service" "$color" "$state" "$reset" \
        "$status" "${cpu:--}" "${memory:--}" "${ports:--}"
    done <<ROWS
$rows
ROWS
  fi
  printf '\n%su%s up all  %ss%s stop all  %sd%s down  %sa%s start  %sx%s stop  %sr%s restart  %sl%s logs  %se%s shell  %sq%s quit\n' \
    "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset"
}

# One key, or nothing after three seconds.
key() {
  stty -icanon -echo min 0 time 30 2>/dev/null
  pressed=$(dd bs=1 count=1 2>/dev/null)
  restore
  printf '%s[?25l' "$esc"
}

# Asks which container; sets NAME and SERVICE, or fails. `all` also
# accepts Enter, meaning every container (NAME and SERVICE empty).
choose() {
  restore
  if [ "$2" = all ]; then printf '\n%s which? (number, Enter for all) ' "$1"; else printf '\n%s which? (number) ' "$1"; fi
  read -r answer
  NAME='' SERVICE=''
  if [ -z "$answer" ]; then [ "$2" = all ]; return; fi
  case "$answer" in *[!0-9]*) return 1 ;; esac
  row "$answer"
}

# Runs a command in the foreground; says so and waits when it fails.
run() {
  restore
  printf '\n%s$ %s%s\n' "$dim" "$*" "$reset"
  following=1
  "$@"
  status=$?
  following=
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then
    printf '%sExited %s. Press Enter.%s' "$red" "$status" "$reset"
    read -r _
  fi
}

shell_in() {
  if [ "$MODE" = compose ]; then
    run compose exec "$SERVICE" sh -c 'command -v bash >/dev/null && exec bash || exec sh'
  else
    run $ENGINE exec -it "$NAME" sh -c 'command -v bash >/dev/null && exec bash || exec sh'
  fi
}

all_names() { printf '%s\n' "$rows" | cut -f1 | grep -v '^-$' | tr '\n' ' '; }

printf '%s[?25l' "$esc"
while :; do
  draw
  key
  case "$pressed" in
    q|Q) quit ;;
    u)
      # shellcheck disable=SC2046 # One argument per container.
      if [ "$MODE" = compose ]; then run compose up -d; else run $ENGINE start $(all_names); fi ;;
    s)
      # shellcheck disable=SC2046
      if [ "$MODE" = compose ]; then run compose stop; else run $ENGINE stop $(all_names); fi ;;
    d)
      restore
      if [ "$MODE" = compose ]; then
        printf '\nStop and remove every container (volumes stay)? [y/N] '
        read -r sure
        case "$sure" in y|Y) run compose down ;; esac
      else
        # shellcheck disable=SC2046
        run $ENGINE stop $(all_names)
      fi ;;
    a) if choose Start one; then
         if [ "$MODE" = compose ]; then run compose up -d "$SERVICE"; else run $ENGINE start "$NAME"; fi
       fi ;;
    x) if choose Stop one; then
         if [ "$MODE" = compose ]; then run compose stop "$SERVICE"; else run $ENGINE stop "$NAME"; fi
       fi ;;
    r) if choose Restart all; then
         if [ -z "$SERVICE" ]; then
           # shellcheck disable=SC2046
           if [ "$MODE" = compose ]; then run compose restart; else run $ENGINE restart $(all_names); fi
         elif [ "$MODE" = compose ]; then run compose restart "$SERVICE"
         else run $ENGINE restart "$NAME"
         fi
       fi ;;
    l) if choose Logs all; then
         printf '%sCtrl-C to come back%s\n' "$dim" "$reset"
         if [ "$MODE" = compose ]; then
           if [ -n "$SERVICE" ]; then run compose logs -f --tail 200 "$SERVICE"; else run compose logs -f --tail 200; fi
         elif [ -n "$NAME" ]; then run $ENGINE logs -f --tail 200 "$NAME"
         fi
       fi ;;
    e) if choose Shell one; then shell_in; fi ;;
  esac
done
