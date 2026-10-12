#!/bin/sh
# The Vercel button at the right of the tab bar: the project, what's in
# production, the branch's newest deployment and the recent ones, each
# with what can be done to it, printed as JSON for Octet.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
find_project
case $? in
  0) ;;
  2)
    echo '{"badge":"link","tone":"muted","message":"This folder has a vercel.json but isn'"'"'t linked to a Vercel project yet.","actions":[{"id":"link","title":"Link Project","symbol":"link"}]}'
    exit 0 ;;
  *) exit 0 ;;
esac
if ! vercel_token; then
  echo '{"badge":"sign in","tone":"muted","message":"Sign in to Vercel to see this project'"'"'s deployments, or add a token in Settings › Plugins › Vercel.","actions":[{"id":"login","title":"Sign In","symbol":"person.crop.circle"}]}'
  exit 0
fi
if ! fetch 8; then
  echo '{"badge":"off","tone":"muted","message":"Vercel didn'"'"'t answer. Check the token in Settings › Plugins › Vercel, or your connection.","actions":[{"id":"login","title":"Sign In Again","symbol":"person.crop.circle"}]}'
  exit 0
fi
js panel "$CACHE_PROJECT" "$CACHE_DEPLOYMENTS" "$(branch)"
