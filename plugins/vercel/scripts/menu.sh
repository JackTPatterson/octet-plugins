#!/bin/sh
# The right-click menu's Vercel items: each prints a Vercel CLI command
# Octet runs in a new tab of the workspace, in the project's folder.
. "$OCTET_PLUGIN_DIR/scripts/lib.sh"
find_project
case $? in
  0) ;;
  2) [ "$1" = link ] || { echo "message: Link this folder to a Vercel project first"; exit 0; } ;;
  *) echo "message: No Vercel project here"; exit 0 ;;
esac
VERCEL=$(cli)
name=$(basename "$PROJECT_DIR")
case $1 in
  deploy) echo "$VERCEL deploy"; echo "label: $name · deploy" ;;
  dev) echo "$VERCEL dev"; echo "label: $name · vercel dev" ;;
  env) echo "$VERCEL env pull"; echo "label: $name · env pull" ;;
  link) echo "$VERCEL link"; echo "label: $name · vercel link" ;;
esac
echo "cwd: $PROJECT_DIR"
