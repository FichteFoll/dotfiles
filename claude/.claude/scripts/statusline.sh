#!/bin/bash

CYAN='\033[36m'
RESET='\033[0m'

read -r input

DIR=$(jq -r '.workspace.current_dir' <<< "$input")
MODEL=$(jq -r '.model.display_name' <<< "$input")
EFFORT=$(jq -r '.effort.level // empty' <<< "$input")

BRANCH=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi

STATUS="$DIR"
[ -n "$BRANCH" ] && STATUS="$STATUS:${CYAN}${BRANCH}${RESET}"
STATUS="$STATUS | $MODEL"
[ -n "$EFFORT" ] && STATUS="$STATUS | effort: $EFFORT"

printf '%b\n' "$STATUS"
