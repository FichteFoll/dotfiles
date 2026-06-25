#!/bin/bash

CYAN='\033[36m'
RESET='\033[0m'

read -r input

DIR=$(jq -r '.workspace.current_dir' <<< "$input")
MODEL=$(jq -r '.model.display_name' <<< "$input")
EFFORT=$(jq -r '.effort.level // empty' <<< "$input")
CTX_TOTAL=$(jq -r '(.context_window.total_input_tokens / 100 | floor | . / 10 | tostring) + "K"' <<< "$input")
CTX_PCT=$(jq -r '(.context_window.used_percentage | round | tostring) + "%"' <<< "$input")
COST=$(jq -r '.cost.total_cost_usd | "$" + (. * 1000 | round | . / 1000 | tostring)' <<< "$input")

BRANCH=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi

STATUS1="$DIR"
[ -n "$BRANCH" ] && STATUS1="$STATUS1:${CYAN}${BRANCH}${RESET}"
STATUS2="$MODEL"
[ -n "$EFFORT" ] && STATUS2="$STATUS2 | effort: $EFFORT"
STATUS2="$STATUS2 | ctx: ${CTX_TOTAL:-ERR} (${CTX_PCT:-0%})"
STATUS2="$STATUS2 | $COST"
STATUS2="[ $STATUS2 ]"

printf '%b\n%b\n' "$STATUS1" "$STATUS2"
