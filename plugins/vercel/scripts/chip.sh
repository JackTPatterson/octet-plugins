#!/bin/sh
# The status bar chip: how the branch's newest deployment went, else
# what's in production. Click to open it, or its build logs.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
find_project || exit 0
if ! vercel_token; then
  echo "Vercel"
  echo "tone: muted"
  if [ -n "$OCTET_PLUGIN_SETTINGS_URL" ]; then
    echo "help: Click to connect Vercel: add a token, or sign in with vercel login"
    echo "url: $OCTET_PLUGIN_SETTINGS_URL"
  else
    echo "help: Sign in with vercel login, or add a token in Settings › Plugins › Vercel"
    echo "url: https://vercel.com/account/tokens"
  fi
  exit 0
fi
if ! fetch 8; then
  echo "Vercel"
  echo "tone: muted"
  echo "help: Vercel didn't answer. Check the token in Settings › Plugins › Vercel, or your connection"
  [ -n "$OCTET_PLUGIN_SETTINGS_URL" ] && echo "url: $OCTET_PLUGIN_SETTINGS_URL"
  exit 0
fi
js chip "$CACHE_PROJECT" "$CACHE_DEPLOYMENTS" "$(branch)"
