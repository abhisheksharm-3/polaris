#!/usr/bin/env bash
# Every target a flow phase can name, with its one-line description.
#
# This is what the composer reads. It exists so a composed flow cannot name a target that is not
# there: the composer picks from this list rather than from memory, and check-flows.sh refuses the
# seed if it picks anything else. Two independent guards on the same failure, because a phase
# pointing at nothing is a run that stalls with no error.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"

# An agent writes its description as a YAML block scalar and a command writes it inline, so taking
# the text after the colon yields a bare pipe for half the fleet. Fall through to the first
# indented line when that happens.
describe() {
    awk '
        NR==1 && /^---/ { f=1; next }
        f && /^---/ { exit }
        f && /^description:/ {
            line = $0; sub(/^description:[[:space:]]*/, "", line)
            if (line != "" && line != "|" && line != ">" && line != "|-" && line != ">-") { print line; exit }
            block = 1; next
        }
        block && /^[[:space:]]+[^[:space:]]/ {
            sub(/^[[:space:]]+/, ""); print; exit
        }
        block && /^[^[:space:]]/ { exit }
    ' "$1" | tr -d '\r' | cut -c1-100
}

for f in "${ROOT}"/agents/*.md; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .md)"
    printf 'agent:%s\t%s\n' "$n" "$(describe "$f")"
done

for f in "${ROOT}"/commands/*.md; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .md)"
    printf 'command:%s\t%s\n' "$n" "$(describe "$f")"
done

for f in "${ROOT}"/workflows/*.js; do
    [ -f "$f" ] || continue
    printf 'workflow:%s\t%s\n' "$(basename "$f" .js)" "a fan-out workflow"
done

printf 'inline\t%s\n' "the session does this phase itself, with no dispatch"
printf 'specialist\t%s\n' "the fleet agent that fits, chosen when the phase runs"
