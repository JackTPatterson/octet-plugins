#!/bin/sh
# The Jira issue the branch is named for (ENG-142-retry, feature/eng-142):
# its key and status, its summary on hover, and a link to it.
. "$OCTET_PLUGIN_DIR/scripts/jira-lib.sh"
branch=$(git symbolic-ref --short HEAD 2>/dev/null) || exit 0
key=$(printf '%s' "$branch" | grep -oE '[A-Za-z][A-Za-z0-9]{1,9}-[0-9]+' | head -n 1 | tr '[:lower:]' '[:upper:]')
[ -n "$key" ] || exit 0
# Standards that look like keys: utf-8, iso-8601, sha-256.
case "${key%%-*}" in UTF|ISO|SHA|RFC|MD|HTTP|IPV|WCAG|ES|PEP) exit 0 ;; esac
# Without its status, the key alone: still a link to the issue when the
# site is known, else to where a Jira API token is made.
key_only() {
  echo "$key"
  echo "tone: muted"
  echo "help: $1"
  if [ -n "$JIRA_URL" ]; then
    echo "url: $JIRA_URL/browse/$key"
  elif [ -n "$OCTET_PLUGIN_SETTINGS_URL" ]; then
    # Octet asks for what's missing in its own settings.
    echo "url: $OCTET_PLUGIN_SETTINGS_URL"
  else
    echo "url: https://id.atlassian.com/manage-profile/security/api-tokens"
  fi
}
if ! jira_config; then
  if [ -n "$OCTET_PLUGIN_SETTINGS_URL" ]; then
    # Octet asks for what's missing right on the chip.
    echo "$key"
    echo "tone: muted"
    echo "help: Click to connect Jira and see $key's status"
    echo "url: $OCTET_PLUGIN_SETTINGS_URL"
  elif [ -n "$JIRA_URL" ]; then
    key_only "Open $key in Jira. For its status here, add your email and an API token in Settings › Plugins › Issues"
  else
    key_only "Connect Jira to open and see this issue: put JIRA_URL (e.g. https://acme.atlassian.net), JIRA_EMAIL and JIRA_API_TOKEN in ~/.config/octet/jira. Click to make a token."
  fi
  exit 0
fi
if ! body=$(jira_get "/rest/api/2/issue/$key?fields=summary,status,assignee"); then
  key_only "Open $key in Jira. Jira didn't answer with its status: check the email and API token in Settings › Plugins › Issues, or that the issue exists"
  exit 0
fi
json '(function(){
  var f = d.fields, s = f.status || {}, cat = (s.statusCategory || {}).key;
  var tone = cat === "done" ? "success" : cat === "new" ? "muted" : "normal";
  var who = f.assignee ? f.assignee.displayName : "Unassigned";
  return d.key + " · " + s.name + "\ntone: " + tone
    + "\nhelp: " + String(f.summary).replace(/\n/g, " ") + "\\n" + who
    + "\nurl: " + a[1] + "/browse/" + d.key;
})()' "$body" "$JIRA_URL"
