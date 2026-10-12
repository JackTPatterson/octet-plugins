#!/bin/sh
# Shared by the Vercel scripts: who you are, which project this folder is,
# and one request to Vercel's API.
#
# The token, first found wins:
#   Octet's Settings › Plugins › Vercel, handed over as VERCEL_TOKEN
#   The Vercel CLI's own sign-in (`vercel login`), so a signed-in CLI
#   needs nothing set here
#
# The project is the one `vercel link` wrote to .vercel/project.json in
# the folder or one above it, up to the repository's root; in a monorepo
# linked with `vercel link --repo`, the one in .vercel/repo.json whose
# directory holds the folder.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
API=https://api.vercel.com

# Sets VERCEL_TOKEN, or fails when there's no sign-in to be found.
vercel_token() {
  [ -n "$VERCEL_TOKEN" ] && return 0
  data=${XDG_DATA_HOME:-$HOME/.local/share}
  for file in "$HOME/Library/Application Support/com.vercel.cli/auth.json" \
              "$data/com.vercel.cli/auth.json" "$HOME/.vercel/auth.json" "$HOME/.now/auth.json"; do
    [ -f "$file" ] || continue
    VERCEL_TOKEN=$(field token "$file")
    [ -n "$VERCEL_TOKEN" ] && return 0
  done
  return 1
}

# A string value from a small JSON file, by key.
field() {
  sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$2" | head -n 1
}

# Sets PROJECT_DIR, PROJECT_ID and ORG_ID for the folder in OCTET_CWD.
# Fails with 2 when the folder is meant for Vercel (a vercel.json) but
# isn't linked yet, setting only PROJECT_DIR; with 1 when it's neither.
find_project() {
  here=${OCTET_CWD:-$PWD}
  top=${OCTET_REPO_ROOT:-$here}
  dir=$here
  while :; do
    if [ -f "$dir/.vercel/project.json" ]; then
      PROJECT_DIR=$dir
      PROJECT_ID=$(field projectId "$dir/.vercel/project.json")
      ORG_ID=$(field orgId "$dir/.vercel/project.json")
      [ -n "$PROJECT_ID" ] && return 0
    fi
    if [ -f "$dir/.vercel/repo.json" ]; then
      relative=${here#"$dir"}
      relative=${relative#/}
      found=$(js repo-project "$(cat "$dir/.vercel/repo.json")" "$relative")
      if [ -n "$found" ]; then
        PROJECT_ID=${found%%"$TAB"*}
        rest=${found#*"$TAB"}
        ORG_ID=${rest%%"$TAB"*}
        sub=${rest#*"$TAB"}
        PROJECT_DIR=$dir${sub:+/$sub}
        return 0
      fi
    fi
    if [ "$dir" = "$top" ] || [ "$dir" = / ]; then break; fi
    dir=$(dirname "$dir")
  done
  dir=$here
  while :; do
    if [ -f "$dir/vercel.json" ]; then PROJECT_DIR=$dir; return 2; fi
    if [ "$dir" = "$top" ] || [ "$dir" = / ]; then break; fi
    dir=$(dirname "$dir")
  done
  return 1
}

TAB=$(printf '\t')

# A request to Vercel's API: `api METHOD PATH [BODY]`. Prints the body,
# and fails on an HTTP error (the body then says why). The token goes to
# curl on stdin, never on its command line; the team comes from the link.
api() {
  method=$1 path=$2 body=${3:-}
  case $path in *\?*) url="$API$path&" ;; *) url="$API$path?" ;; esac
  case $ORG_ID in team_*) url="${url}teamId=$ORG_ID" ;; esac
  url=${url%[?&]}
  config=$(printf 'header = "Authorization: Bearer %s"' "$VERCEL_TOKEN")
  if [ -n "$body" ]; then
    out=$(printf '%s\n' "$config" | curl -s --max-time 10 -K - -X "$method" \
      -H 'Content-Type: application/json' --data-binary "$body" -w '\n%{http_code}' "$url") || return 1
  else
    out=$(printf '%s\n' "$config" | curl -s --max-time 10 -K - -X "$method" -w '\n%{http_code}' "$url") || return 1
  fi
  code=${out##*"
"}
  printf '%s\n' "${out%"
"*}"
  case $code in 2*) return 0 ;; *) return 1 ;; esac
}

# The project and its recent deployments, as two files read by `js`.
# Fetched at most every few seconds, so the chip, the panel and
# completions share one fetch.
CACHE_PROJECT='' CACHE_DEPLOYMENTS=''
fetch() {
  cache="${TMPDIR:-/tmp}/octet-vercel-$(id -u)"
  mkdir -p "$cache" 2>/dev/null && chmod 700 "$cache" 2>/dev/null
  CACHE_PROJECT="$cache/$PROJECT_ID.project.json"
  CACHE_DEPLOYMENTS="$cache/$PROJECT_ID.deployments.json"
  stamp="$cache/$PROJECT_ID.stamp"
  now=$(date +%s)
  if [ -f "$stamp" ] && [ -s "$CACHE_DEPLOYMENTS" ] && [ $((now - $(cat "$stamp"))) -lt "${1:-8}" ]; then
    return 0
  fi
  project=$(api GET "/v9/projects/$PROJECT_ID") || return 1
  deployments=$(api GET "/v6/deployments?projectId=$PROJECT_ID&limit=20") || return 1
  printf '%s\n' "$project" >"$CACHE_PROJECT"
  printf '%s\n' "$deployments" >"$CACHE_DEPLOYMENTS"
  echo "$now" >"$stamp"
}

# What's cached goes stale after a change, so the panel shows it at once.
forget() {
  rm -f "${TMPDIR:-/tmp}/octet-vercel-$(id -u)/$PROJECT_ID.stamp"
}

# The branch the folder is on.
branch() {
  git -C "${PROJECT_DIR:-.}" symbolic-ref --short HEAD 2>/dev/null
}

# Runs scripts/vercel.js: `js MODE ARGS…`. Every Mac has osascript (not
# every Mac has Node or jq); on Linux it takes Node.
js() {
  script="$OCTET_PLUGIN_DIR/scripts/vercel.js"
  if command -v osascript >/dev/null 2>&1; then
    osascript -l JavaScript "$script" "$@" 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    node "$script" "$@" 2>/dev/null
  fi
}

# The Vercel CLI, for what runs in a tab: the installed one, else the
# latest through npx.
cli() {
  if command -v vercel >/dev/null 2>&1; then echo vercel; else echo "npx --yes vercel@latest"; fi
}

# `word` quoted for sh.
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}
