#!/usr/bin/env bash
# Deterministic work-tracker snapshot: what happened in one project since a timestamp.
# Emits factual markdown that the SessionStart reconcile directive hands to a background
# agent. The agent classifies it into work streams, the part a shell hook cannot do (spec
# docs/specs/2026-07-15-slice-worktracker-mvp.md, "Honest scope").
set -uo pipefail

project="${1:?usage: worktracker-snapshot.sh <project-dir> <since-utc>}"
since="${2:?usage: worktracker-snapshot.sh <project-dir> <since-utc>}"
PROJECTS="${POLARIS_JOURNAL_PROJECTS_DIR:-$HOME/.claude/projects}"

commits="" files="" asks=""

if git -C "$project" rev-parse --git-dir >/dev/null 2>&1; then
  commits="$(git -C "$project" log --since="$since" --pretty='%h %s' 2>/dev/null)"
  files="$(git -C "$project" log --since="$since" --name-only --pretty=format: 2>/dev/null \
    | awk 'NF' | sort -u | paste -sd, - | sed 's/,/, /g')"
fi

# Prompts asked in this project since the marker, so work that was not committed still shows.
# `since` is UTC (matches transcript .timestamp); the -newermt pre-filter uses the day only,
# the exact cutoff is the jq timestamp compare.
if [ -d "$PROJECTS" ] && command -v jq >/dev/null 2>&1; then
  since_day="${since%%T*}"
  asks="$(find "$PROJECTS" -type f -name '*.jsonl' -newermt "$since_day 00:00" -print0 2>/dev/null \
    | xargs -0 -r jq -rc --arg since "$since" --arg cwd "$project" '
        select(.cwd == $cwd) |
        select((.timestamp // "") >= $since) |
        select(.isSidechain != true) |
        select((.message.role // .type) == "user") |
        ( (.message.content // "")
          | if type=="array" then (map(select(.type=="text") | .text) | join(" "))
            elif type=="string" then . else "" end )
      ' 2>/dev/null \
    | sed 's/\\n.*//' \
    | grep -vE '^(\[Image|<task-notification|\[SYSTEM NOTIFICATION|\[Request interrupted|<command-|<fork-boilerplate|Base directory|Caveat:|You are a )' \
    | cut -c1-120 | awk 'NF' | awk '!seen[$0]++' | head -20 | paste -sd';' - | sed 's/;/; /g')"
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
