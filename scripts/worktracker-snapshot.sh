#!/usr/bin/env bash
# Deterministic work-tracker snapshot: what happened in one project since a timestamp.
# Emits factual markdown that the Stop hook (hooks/stop-capture) hands to the agent inline. The
# agent classifies it into work streams, the part a shell hook cannot do (spec
# docs/specs/2026-07-15-slice-worktracker-mvp.md, "Honest scope").
set -uo pipefail

project="${1:?usage: worktracker-snapshot.sh <project-dir> <since-utc>}"
since="${2:?usage: worktracker-snapshot.sh <project-dir> <since-utc>}"
HISTORY="${POLARIS_HISTORY_FILE:-$HOME/.claude/history.jsonl}"

commits="" files="" asks=""

if git -C "$project" rev-parse --git-dir >/dev/null 2>&1; then
  commits="$(git -C "$project" log --since="$since" --pretty='%h %s' 2>/dev/null)"
  files="$(git -C "$project" log --since="$since" --name-only --pretty=format: 2>/dev/null \
    | awk 'NF' | sort -u | paste -sd, - | sed 's/,/, /g')"
fi

# Prompts asked in this project since the marker, so work that was not committed still shows.
# `history.jsonl` holds one record per typed prompt, with `display`, `project`, and an epoch-ms
# `timestamp`. The earlier source was the session transcripts, which carry every user-role turn:
# hook-injected context, tool results, and a workflow agent's own prompt all arrived as the question
# the user asked, and three snapshots reconciled against the wrong text before this changed.
if [ -f "$HISTORY" ] && command -v jq >/dev/null 2>&1; then
  since_ms="$(jq -rn --arg s "$since" 'try ((($s | fromdateiso8601) * 1000) | floor) catch empty')"
  if [ -n "$since_ms" ]; then
    asks="$(jq -r --argjson since "$since_ms" --arg cwd "$project" '
          select(.project == $cwd) |
          select((.timestamp // 0) >= $since) |
          (.display // "") | gsub("[\n\r\t]+"; " ")
        ' "$HISTORY" 2>/dev/null \
      | cut -c1-120 | awk 'NF' | awk '!seen[$0]++' | head -20 | paste -sd';' - | sed 's/;/; /g')"
  fi
fi

# Nothing happened since the last reconcile: emit nothing, and the hook injects no directive.
[ -n "$commits" ] || [ -n "$asks" ] || exit 0

printf '### Activity since %s\n' "$since"
[ -n "$asks" ]    && printf -- '- Asked: %s\n' "$asks"
if [ -n "$commits" ]; then
  printf -- '- Commits:\n'
  printf '%s\n' "$commits" | sed 's/^/    /'
fi
[ -n "$files" ]   && printf -- '- Files: %s\n' "$files"
