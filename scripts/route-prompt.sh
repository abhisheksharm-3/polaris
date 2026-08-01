#!/usr/bin/env bash
# Classify a prompt on stdin into a flow from rules/flows.json, or print unknown.
# This is the free pass: it runs on every prompt, so it spends no tokens and holds no judgment.
# What it cannot place it leaves to the composer, which is the expensive path by design.
#
# Ordered first match, not best match. The order in patterns.json is the policy: a prompt naming an
# outage is an incident even when it also says the word broken, and a prompt asking what something
# does is a question even when it names a feature. Scoring across classes would make that order
# implicit and the misroutes hard to argue with; a list you read top to bottom is arguable.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PATTERNS="${ROOT}/rules/patterns.json"

command -v jq >/dev/null 2>&1 || { echo unknown; exit 0; }
[ -f "$PATTERNS" ] || { echo unknown; exit 0; }

prompt="$(tr '[:upper:]' '[:lower:]' | tr '\n' ' ')"
[ -n "${prompt// /}" ] || { echo unknown; exit 0; }

# One field per line, not a separated record. @tsv escapes the backslash in every word boundary,
# so a pattern reaches grep as literal \\b and matches nothing, and no printable separator is safe
# when the field it separates is a regex. A pattern cannot contain a newline, so lines can.
while read -r class && read -r pattern; do
    [ -n "$class" ] || continue
    if printf '%s' "$prompt" | grep -Eq "$pattern"; then
        echo "$class"
        exit 0
    fi
done < <(jq -r '.routing[] | .class as $c | .patterns[] | $c, .' "$PATTERNS")

echo unknown
