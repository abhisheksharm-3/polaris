#!/usr/bin/env bash
# Validate a flow catalog: every phase names a dispatch target that resolves.
# A flow is data, so a typo in a target is a silent dead phase at run time rather than a load
# error. This is the only thing that catches it. Takes a catalog path, defaulting to the shipped
# one, so the composer can validate a flow it built before that flow is ever seeded.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
CATALOG="${1:-${ROOT}/rules/flows.json}"
fail=0

command -v jq >/dev/null 2>&1 || { echo "check-flows: jq is required"; exit 1; }
[ -f "$CATALOG" ] || { echo "check-flows: no catalog at ${CATALOG}"; exit 1; }
jq -e . "$CATALOG" >/dev/null 2>&1 || { echo "check-flows: ${CATALOG} is not valid json"; exit 1; }

while IFS=$'\t' read -r flow phase target; do
    [ -n "$flow" ] || continue
    case "$target" in
        # The session model does the phase itself, or picks the fleet agent that fits. Neither
        # names a file, so neither can be resolved here; the phase gate checks them at dispatch.
        inline|specialist) continue ;;
        agent:*)    path="${ROOT}/agents/${target#agent:}.md" ;;
        command:*)  path="${ROOT}/commands/${target#command:}.md" ;;
        # Workflows ship from a directory that does not exist until the fan-out phases are built.
        # Until then an unbuilt workflow target is a known gap, not a broken catalog.
        workflow:*) [ -d "${ROOT}/workflows" ] || continue
                    path="${ROOT}/workflows/${target#workflow:}.js" ;;
        *) echo "${flow}:${phase}: unknown target kind '${target}'"; fail=1; continue ;;
    esac
    [ -f "$path" ] || { echo "${flow}:${phase}: unresolved ${target}"; fail=1; }
done < <(jq -r 'to_entries[] | .key as $f | .value.phases[]? | [$f, .name, .run] | @tsv' "$CATALOG")

# A phase with no run target loads fine and then does nothing, so catch it here rather than at the
# first run that silently skips it.
missing="$(jq -r 'to_entries[] | .key as $f | .value.phases[]? | select(has("run")|not) | "\($f):\(.name): phase has no run target"' "$CATALOG")"
[ -n "$missing" ] && { echo "$missing"; fail=1; }

[ "$fail" = 0 ] && echo "ok: $(jq 'length' "$CATALOG") flows, every target resolves"
exit $fail
