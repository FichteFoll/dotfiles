#!/bin/bash

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'

# Semantic aliases
WARNING="$YELLOW"
DANGER="$RED"

# Formats a usage percentage, colored yellow above 50% and red above 75%.
color_pct() {
    local pct="$1"
    [ -z "$pct" ] && { printf '?'; return; }
    local color=""
    if [ "$pct" -gt 75 ]; then
        color="$DANGER"
    elif [ "$pct" -gt 50 ]; then
        color="$WARNING"
    fi
    [ -n "$color" ] && printf '%b%s%%%b' "$color" "$pct" "$RESET" || printf '%s%%' "$pct"
}

# Colors the model name by family: Opus=magenta (top tier),
# Sonnet=blue (mid), Haiku=green (fast/cheap), Fable=red, else uncolored.
color_model() {
    local model="$1"
    local color=""
    case "$model" in
        *Opus*)   color="$MAGENTA" ;;
        *Sonnet*) color="$BLUE" ;;
        *Haiku*)  color="$GREEN" ;;
        *Fable*)  color="$RED" ;;
    esac
    [ -n "$color" ] && printf '%b%s%b' "$color" "$model" "$RESET" || printf '%s' "$model"
}

# Summarizes the task list stored by the TaskCreate/TaskUpdate tools, one JSON
# file per task. Prints nothing once all tasks are completed, so a finished
# plan disappears from the status line.
task_progress() {
    local files
    shopt -s nullglob
    files=("$1"/*.json)
    shopt -u nullglob
    [ ${#files[@]} -eq 0 ] && return

    local done total running current
    IFS=$'\t' read -r done total running current < <(jq -rs '
        [.[] | select(.status == "in_progress")] as $active
        | [([.[] | select(.status == "completed")] | length), length, ($active | length),
           ($active[0] | .activeForm // .subject // "")]
        | @tsv' "${files[@]}" 2>/dev/null)
    [ -z "$total" ] || [ "$done" -eq "$total" ] && return

    printf 'tasks: %s/%s' "$done" "$total"
    if [ "$running" -eq 1 ]; then
        printf ' %b%s%b' "$DIM" "$current" "$RESET"
    elif [ "$running" -gt 1 ]; then
        printf ' %b(%s running)%b' "$DIM" "$running" "$RESET"
    fi
}

# A hung invocation is not killed by Claude Code for 10 minutes (the default
# hook timeout) while a new one is spawned on every refresh, so never block
# indefinitely on stdin or on git.
read -r -t 5 input

DIR=$(jq -r '.workspace.current_dir' <<< "$input")
MODEL=$(jq -r '.model.display_name' <<< "$input")
EFFORT=$(jq -r '.effort.level // empty' <<< "$input")
CTX_TOTAL=$(jq -r '(.context_window.total_input_tokens / 100 | floor | . / 10 | tostring) + "K"' <<< "$input")
CTX_PCT=$(jq -r '(.context_window.used_percentage | round | tostring) + "%"' <<< "$input")
SESSION_PCT=$(jq -r '.rate_limits.five_hour.used_percentage | round | tostring' <<< "$input" 2>/dev/null)
WEEK_PCT=$(jq -r '.rate_limits.seven_day.used_percentage | round | tostring' <<< "$input" 2>/dev/null)
SESSION_ID=$(jq -r '.session_id // empty' <<< "$input")

BRANCH=""
if timeout 2 git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(timeout 2 git -C "$DIR" branch --show-current 2>/dev/null)
fi

DIR_FMT="$DIR"
for marker in ".claude/worktrees" ".worktrees"; do
    if [[ "$DIR" == *"/$marker/"* ]]; then
        prefix="${DIR%/$marker/*}"
        worktree="${DIR#*/$marker/}"
        DIR_FMT="${prefix}/${WARNING}${marker}/${worktree}${RESET}"
        break
    fi
done
STATUS1="$DIR_FMT"
[ -n "$BRANCH" ] && STATUS1="$STATUS1:${CYAN}${BRANCH}${RESET}"
STATUS2="$(color_model "$MODEL")"
[ -n "$EFFORT" ] && [ "$EFFORT" != "medium" ] && STATUS2="$STATUS2 | effort: $EFFORT"
STATUS2="$STATUS2 | ctx: ${CTX_TOTAL:-ERR} (${CTX_PCT:-0%})"
STATUS2="$STATUS2 | 5h:$(color_pct "$SESSION_PCT") 7d:$(color_pct "$WEEK_PCT")"
if [ -n "${SANDBOX_HOME_CTX:-}" ]; then
    STATUS2="$STATUS2 | sandbox: $SANDBOX_HOME_CTX"
else
    STATUS2="$STATUS2 | ${DANGER}host${RESET}"
fi
# Last, as it changes the most and would shift the segments after it.
# Claude Code stores the task list under the session ID unless a named list is shared.
TASK_LIST_ID="${CLAUDE_CODE_TASK_LIST_ID:-$SESSION_ID}"
if [ -n "$TASK_LIST_ID" ]; then
    TASKS=$(task_progress "$HOME/.claude/tasks/$TASK_LIST_ID")
    [ -n "$TASKS" ] && STATUS2="$STATUS2 | $TASKS"
fi
STATUS2="[ $STATUS2 ]"

printf '%b\n%b\n' "$STATUS1" "$STATUS2"
