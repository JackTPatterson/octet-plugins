#!/bin/sh
# Values while typing: this project's recent deployments for `vercel
# inspect`, `logs`, `promote`, `rollback`, `redeploy` and `remove`, and
# your teams for `vercel switch`.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
vercel_token || exit 0
case $1 in
  teams)
    # Every team you're in, not just the linked one's.
    export ORG_ID=''
    teams=$(api GET "/v2/teams?limit=50") || exit 0
    js complete-teams "$teams" ;;
  *)
    find_project || exit 0
    fetch 20 || exit 0
    js complete-deployments "$CACHE_PROJECT" "$CACHE_DEPLOYMENTS" ;;
esac
