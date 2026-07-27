#!/bin/bash

CYAN='\033[36m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Formats a usage percentage, colored yellow above 50% and red above 75%.
color_pct() {
    local pct="$1"
    [ -z "$pct" ] && { printf '?'; return; }
    local color=""
    if [ "$pct" -gt 75 ]; then
        color="$RED"
    elif [ "$pct" -gt 50 ]; then
        color="$YELLOW"
    fi
    [ -n "$color" ] && printf '%b%s%%%b' "$color" "$pct" "$RESET" || printf '%s%%' "$pct"
}

read -r input

DIR=$(jq -r '.workspace.current_dir' <<< "$input")
MODEL=$(jq -r '.model.display_name' <<< "$input")
EFFORT=$(jq -r '.effort.level // empty' <<< "$input")
CTX_TOTAL=$(jq -r '(.context_window.total_input_tokens / 100 | floor | . / 10 | tostring) + "K"' <<< "$input")
CTX_PCT=$(jq -r '(.context_window.used_percentage | round | tostring) + "%"' <<< "$input")
SESSION_PCT=$(jq -r '.rate_limits.five_hour.used_percentage | round | tostring' <<< "$input" 2>/dev/null)
WEEK_PCT=$(jq -r '.rate_limits.seven_day.used_percentage | round | tostring' <<< "$input" 2>/dev/null)

BRANCH=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi

STATUS1="$DIR"
[ -n "$BRANCH" ] && STATUS1="$STATUS1:${CYAN}${BRANCH}${RESET}"
STATUS2="$MODEL"
[ -n "$EFFORT" ] && STATUS2="$STATUS2 | effort: $EFFORT"
STATUS2="$STATUS2 | ctx: ${CTX_TOTAL:-ERR} (${CTX_PCT:-0%})"
STATUS2="$STATUS2 | 5h:$(color_pct "$SESSION_PCT") 7d:$(color_pct "$WEEK_PCT")"
if [ -n "${SANDBOX_HOME_CTX:-}" ]; then
    STATUS2="$STATUS2 | sandbox: $SANDBOX_HOME_CTX"
else
    STATUS2="$STATUS2 | ${RED}host${RESET}"
fi
STATUS2="[ $STATUS2 ]"

printf '%b\n%b\n' "$STATUS1" "$STATUS2"
