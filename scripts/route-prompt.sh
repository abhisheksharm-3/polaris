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

# The instruction is in the opening lines, never in a log pasted below it, so classify the first 4,000
# characters. Without the cap a 160 KB paste took over two minutes and blocked the prompt: the old
# blank check, ${prompt// /}, is quadratic in bash 3.2, which is the bash macOS ships.
prompt="$(head -c 4000 | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')"
case "$prompt" in *[![:space:]]*) ;; *) echo unknown; exit 0 ;; esac

# One jq pass over the whole table. The router runs on every prompt the user types, and spawning a
# grep per pattern cost about 0.25 s a prompt at 186 patterns, growing with every class added. jq's
# regex engine (Oniguruma) reads the same \b and [[:space:]] the table is written in, and first()
# keeps the ordered first-match policy described above.
jq -r --arg p "$prompt" \
    'first(.routing[] | select(any(.patterns[]; . as $re | $p | test($re))) | .class) // "unknown"' \
    "$PATTERNS" 2>/dev/null || echo unknown
