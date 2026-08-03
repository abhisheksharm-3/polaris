#!/usr/bin/env bash
# The open run, for the status line: which flow, which phase, how far along, and what it waits on.
# Run state that is not visible gets forgotten, and a forgotten run is a gate refusing dispatches
# for a reason nobody remembers.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

command -v jq >/dev/null 2>&1 || exit 0
state="$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "${SCRIPT_DIR}/run-state.sh" get 2>/dev/null)" || exit 0
[ -n "$state" ] || exit 0

slug="$(printf '%s' "$state" | jq -r .slug)"
flow="$(printf '%s' "$state" | jq -r .flow)"
phase="$(printf '%s' "$state" | jq -r .current)"
[ -n "$phase" ] && [ "$phase" != "null" ] || { printf 'polaris: %s · done\n' "$slug"; exit 0; }

names="$(printf '%s' "$state" | jq -r 'if has("phases") then .phases[].name else empty end')"
[ -n "$names" ] || names="$(jq -r --arg f "$flow" '.[$f].phases[].name' "${ROOT}/rules/flows.json" 2>/dev/null)"
total="$(printf '%s\n' "$names" | grep -c .)"
at="$(printf '%s\n' "$names" | grep -nxF "$phase" | cut -d: -f1)"

waiting=""
[ "$(printf '%s' "$state" | jq -r --arg p "$phase" '.record[$p].status // ""')" = "done" ] \
    && waiting=" · awaiting approval"
printf 'polaris: %s · %s %s/%s%s\n' "$slug" "$phase" "${at:-?}" "$total" "$waiting"
