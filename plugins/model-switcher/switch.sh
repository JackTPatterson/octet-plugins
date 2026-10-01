#!/bin/sh
# Picks the model and effort for an Octet conversation's next turn from how
# much of the account's allowance is used. Octet sets OCTET_AGENT,
# OCTET_MODEL, OCTET_EFFORT, OCTET_MODELS, OCTET_EFFORTS and an
# OCTET_USAGE_<WINDOW> percentage for each window; printing nothing keeps
# the person's own pick (and brings it back once usage is under the limits).

number() { case "$1" in ''|*[!0-9]*) echo "$2" ;; *) echo "$1" ;; esac; }
effort_at=$(number "$EFFORT_DOWN_AT" 70)
model_at=$(number "$MODEL_DOWN_AT" 85)
last_at=$(number "$LAST_RESORT_AT" 95)

model=$(printf '%s' "$OCTET_MODEL" | tr '[:upper:]' '[:lower:]')

# The fullest window that applies: every window, except that one for a
# family of models (7d Opus) counts only while on that family.
usage=0
window=""
for entry in $(env | grep '^OCTET_USAGE_[A-Z0-9_]*=[0-9][0-9]*$'); do
    name=${entry%%=*}
    value=${entry#*=}
    rest=${name#OCTET_USAGE_}
    family=$(printf '%s' "${rest#*_}" | tr '[:upper:]' '[:lower:]')
    if [ "$family" != "$(printf '%s' "$rest" | tr '[:upper:]' '[:lower:]')" ]; then
        case "$model" in *"$family"*) ;; *) continue ;; esac
    fi
    if [ "$value" -gt "$usage" ]; then
        usage=$value
        window=$(printf '%s' "$rest" | tr 'A-Z_' 'a-z ')
    fi
done

[ "$usage" -ge "$effort_at" ] || exit 0

# The first model the agent offers whose id has `pattern` in it.
offered() {
    for id in $OCTET_MODELS; do
        case "$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')" in *"$1"*) echo "$id"; return ;; esac
    done
}

if [ "$OCTET_AGENT" = codex ]; then
    smaller=$(printf '%s' "${CODEX_SMALLER:-mini}" | tr '[:upper:]' '[:lower:]')
    smallest=$smaller
else
    smaller=$(printf '%s' "${CLAUDE_SMALLER:-sonnet}" | tr '[:upper:]' '[:lower:]')
    smallest=$(printf '%s' "${CLAUDE_SMALLEST:-haiku}" | tr '[:upper:]' '[:lower:]')
fi

# Effort only ever goes down: a pick already at or under it stays.
rank() {
    case "$1" in
        minimal) echo 0 ;; low) echo 1 ;; medium) echo 2 ;; high) echo 3 ;;
        xhigh) echo 4 ;; max) echo 5 ;; ultracode) echo 6 ;; '') echo 3 ;; *) echo 3 ;;
    esac
}
lower_to() {
    if [ "$(rank "$OCTET_EFFORT")" -gt "$(rank "$1")" ]; then echo "effort: $1"; fi
}

if [ "$usage" -ge "$last_at" ]; then
    case "$model" in
        *"$smallest"*) ;;
        *) target=$(offered "$smallest"); [ -n "$target" ] && echo "model: $target" ;;
    esac
    lower_to low
elif [ "$usage" -ge "$model_at" ]; then
    case "$model" in
        *"$smaller"*|*"$smallest"*) ;;
        *) target=$(offered "$smaller"); [ -n "$target" ] && echo "model: $target" ;;
    esac
    lower_to medium
else
    lower_to medium
fi

when=""
if [ -n "$OCTET_USAGE_RESETS_AT" ]; then
    when=$(date -r "$OCTET_USAGE_RESETS_AT" '+%a %H:%M' 2>/dev/null || date -d "@$OCTET_USAGE_RESETS_AT" '+%a %H:%M' 2>/dev/null)
fi
echo "message: ${window:-usage} window at $usage%${when:+, until it resets $when}"
