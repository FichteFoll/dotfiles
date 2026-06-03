#!/usr/bin/env bash
# Injects AGENTS.md into context once per Claude Code session.
session_id=$(jq -r .session_id)
marker_dir="/tmp/cc-agents"
mkdir -p "$marker_dir"
marker="$marker_dir/$session_id"

[ -f AGENTS.md ] || exit 0
[ -f "$marker" ] && exit 0

touch "$marker"
printf '<agents-md>\n'
cat AGENTS.md
printf '</agents-md>\n'
