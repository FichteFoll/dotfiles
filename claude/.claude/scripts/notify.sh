#!/usr/bin/env bash
# Desktop notification, sound and terminal bell for Claude Code notifications.
#
# Replaces the built-in notification channel, which is turned off via
# "preferredNotifChannel": "notifications_disabled" in settings.json, so that
# the idle notification can be suppressed while async agents are still running.
# Claude Code fires idle_prompt whenever the main loop yields to the prompt,
# including when it only yields to wait for background agents; there is no
# built-in way to tell those cases apart. See the upstream request
# https://github.com/anthropics/claude-code/issues/45781 (closed as not
# planned), which asks for a dedicated event for "idle with no live children".
#
# The bell cannot be written to /dev/tty: hooks run without a controlling
# terminal since v2.1.139. It is returned as a terminalSequence instead, which
# Claude Code emits through its own terminal write path (requires v2.1.141+).
set -euo pipefail

input=$(cat)
ntype=$(jq -r '.notification_type // empty' <<< "$input")
cwd=$(jq -r '.cwd // empty' <<< "$input")
session=$(jq -r '.session_id // empty' <<< "$input")
transcript=$(jq -r '.transcript_path // empty' <<< "$input")
message=$(jq -r '.message // empty' <<< "$input")

# Identifies the session in a notification that may come from any of several
# terminal windows. The bell tells you which window, this tells you which repo.
label() {
    local project branch
    project=$(basename "$cwd")
    branch=""
    if timeout 2 git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(timeout 2 git -C "$cwd" branch --show-current 2>/dev/null)
    fi
    printf '%s%s [%s]' "$project" "${branch:+ ($branch)}" "${session:0:8}"
}

# An async agent is outstanding when its launch has no matching task
# notification yet. The launch result is written to the transcript immediately,
# so unanswered tool_use ids cannot be used for this.
agents_pending() {
    [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
    local launched finished
    launched=$(jq -r '
        select((.message.content? | type) == "array")
        | .message.content[]
        | select(.type == "tool_result")
        | select((.content | tostring) | test("Async agent launched successfully"))
        | .tool_use_id' "$transcript" 2>/dev/null | sort -u)
    [ -n "$launched" ] || return 1
    finished=$(grep -o '<tool-use-id>[^<]*</tool-use-id>' "$transcript" \
        | sed 's/<[^>]*>//g' | sort -u)
    grep -qvxF -f <(printf '%s\n' "$finished") <<< "$launched"
}

case "$ntype" in
    idle_prompt)
        agents_pending && exit 0
        notify-send 'Claude Code' "Session finished: $(label)" > /dev/null 2>&1
        ;;
    permission_prompt)
        notify-send --urgency=critical 'Claude Code' "$message: $(label)" > /dev/null 2>&1
        ;;
    *)
        exit 0
        ;;
esac

paplay ~/.claude/sounds/notify.flac > /dev/null 2>&1 &

# Only the JSON may go to stdout, everything else above is silenced for that.
jq -nc --arg seq "$(printf '\007')" '{terminalSequence: $seq, suppressOutput: true}'
