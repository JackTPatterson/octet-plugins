#!/bin/sh
# Does what was clicked in the Vercel panel. OCTET_ACTION says what, and
# OCTET_ITEM which deployment (`<uid>|<host>|<target>`). Promote, roll
# back, redeploy and cancel go straight to Vercel's API; deploys, logs and
# pulling the environment print a Vercel CLI command, which Octet opens in
# a new tab, so its output can be watched.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
find_project
linked=$?
[ "$linked" -eq 1 ] && { echo "message: No Vercel project here"; exit 0; }
uid=${OCTET_ITEM%%|*}
rest=${OCTET_ITEM#*|}
host=${rest%%|*}
target=${rest#*|}
name=$(basename "$PROJECT_DIR")
VERCEL=$(cli)

# A command for a new tab, in the project's folder.
tab() {
  echo "$1"
  echo "label: $2"
  echo "cwd: $PROJECT_DIR"
}

# A change made through the API, then said in a line; the panel reads
# Vercel again right after.
change() {
  vercel_token || { tab "$VERCEL $3" "$name · vercel"; return; }
  if out=$(api "$1" "$2" "${4:-}"); then
    forget
    echo "message: $5"
  else
    echo "message: $(js error "$out" "Vercel didn't accept that")"
  fi
}

case "$OCTET_ACTION" in
  link) tab "$VERCEL link" "$name · vercel link" ;;
  login) tab "$VERCEL login" "vercel login" ;;
  deploy) tab "$VERCEL deploy" "$name · deploy" ;;
  deploy-prod) tab "$VERCEL deploy --prod" "$name · deploy to production" ;;
  env) tab "$VERCEL env pull" "$name · env pull" ;;
  dev) tab "$VERCEL dev" "$name · vercel dev" ;;
  logs) tab "$VERCEL inspect $(quote "$host") --logs --wait" "$name · build logs" ;;
  runtime) tab "$VERCEL logs $(quote "$host")" "$name · logs" ;;
  promote)
    change POST "/v10/projects/$PROJECT_ID/promote/$uid" "promote $(quote "$host")" '{}' \
      "Promoting to production. It's live once the build finishes" ;;
  rollback)
    change POST "/v9/projects/$PROJECT_ID/rollback/$uid" "rollback $(quote "$host")" '{}' \
      "Rolled production back. Your domains point at this deployment now" ;;
  cancel)
    vercel_token || { echo "message: Sign in to Vercel to cancel a build"; exit 0; }
    change PATCH "/v12/deployments/$uid/cancel" '' '' "Canceled the build" ;;
  redeploy)
    if ! vercel_token; then tab "$VERCEL redeploy $(quote "$host")" "$name · redeploy"; exit 0; fi
    deployment=$(api GET "/v13/deployments/$uid") || { echo "message: $(js error "$deployment" "Couldn't find that deployment")"; exit 0; }
    what=preview; [ "$target" = production ] && what=production
    change POST "/v13/deployments?forceNew=1" "redeploy $(quote "$host")" "$(js redeploy-body "$deployment")" \
      "Building the $what deployment again" ;;
esac
