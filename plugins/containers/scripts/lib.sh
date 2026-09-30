#!/bin/sh
# Shared by the chip, the menu items and the dashboard: which engine runs
# the containers, and which containers belong to this folder.

# Docker, else Podman; nothing when neither is installed.
engine() {
  if command -v docker >/dev/null 2>&1; then echo docker
  elif command -v podman >/dev/null 2>&1; then echo podman
  fi
}

# Sets PROJECT_DIR, COMPOSE_FILE and MODE for the folder in OCTET_CWD: a
# Compose project in it or a folder above it, up to the repository's root
# (MODE=compose), else a dev container opened on the repository
# (MODE=devcontainer). Fails when the folder has neither.
find_project() {
  here=${OCTET_CWD:-$PWD}
  top=${OCTET_REPO_ROOT:-$here}
  dir=$here
  while :; do
    for file in compose.yaml compose.yml docker-compose.yml docker-compose.yaml; do
      if [ -f "$dir/$file" ]; then
        PROJECT_DIR=$dir COMPOSE_FILE=$file MODE=compose
        return 0
      fi
    done
    if [ "$dir" = "$top" ] || [ "$dir" = / ]; then break; fi
    dir=$(dirname "$dir")
  done
  if [ -d "$top/.devcontainer" ] || [ -f "$top/.devcontainer.json" ]; then
    PROJECT_DIR=$top COMPOSE_FILE='' MODE=devcontainer
    return 0
  fi
  return 1
}

# One line per container, tab-separated: name, service, state, status,
# ports. A Compose service that has no container yet is listed with the
# state "not created". Fails when the engine doesn't answer.
list_containers() {
  tab=$(printf '\t')
  if [ "$MODE" = compose ]; then
    listed=$(cd "$PROJECT_DIR" && $ENGINE compose -f "$COMPOSE_FILE" ps -a \
      --format '{{.Name}}\t{{.Service}}\t{{.State}}\t{{.Status}}\t{{.Ports}}') || return 1
    [ -n "$listed" ] && printf '%s\n' "$listed"
    services=$(cd "$PROJECT_DIR" && $ENGINE compose -f "$COMPOSE_FILE" config --services 2>/dev/null)
    for service in $services; do
      printf '%s\n' "$listed" | cut -f2 | grep -qx "$service" \
        || printf -- '-%s%s%snot created%s%s\n' "$tab" "$service" "$tab" "$tab" "$tab"
    done
  else
    $ENGINE ps -a --filter "label=devcontainer.local_folder=$PROJECT_DIR" \
      --format '{{.Names}}\t{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Ports}}'
  fi
}

# The first port a container publishes on the host, from `ports`.
first_port() {
  printf '%s\n' "$1" | sed -n 's/^[^>]*:\([0-9][0-9]*\)->.*/\1/p' | head -n 1
}

# `word` quoted for sh.
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# `text` as a JSON string.
json() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\t\n' '  ')"
}
