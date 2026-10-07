# The testing standard: its core fits its budget and reaches every code-writing agent.
# covers: rules/testing-core.md hooks/inject-cores hooks/inject-standard hooks/hooks.json agents/*.md commands/*.md rules/*.md
source "$(dirname "$0")/../lib.sh"

# The testing core reaches every session and every agent that writes code, inside its budget.
tc_len="$(wc -c < "${DIR}/../rules/testing-core.md" | tr -d ' ')"
[ "$tc_len" -le 3000 ] && echo "ok: rules/testing-core.md is inside its 3000-byte budget (${tc_len})" \
  || { echo "FAIL: rules/testing-core.md is ${tc_len} bytes"; fail=1; }
jq -e '.hooks.SessionStart[].hooks[] | select(.command | test("inject-cores"))' "${DIR}/../hooks/hooks.json" >/dev/null \
  && echo '{}' | CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/inject-cores" \
    | jq -e '.hookSpecificOutput.additionalContext | test("Name the break first")' >/dev/null \
  && grep -q 'core testing standard' <<<"$(is_ctx polaris:backend)" \
  && grep -q 'core testing standard' <<<"$(is_ctx polaris:test-engineer)" \
  && ! grep -q 'core testing standard' <<<"$(is_ctx polaris:ux)" \
  && echo "ok: the testing core reaches the session and every code-writing agent" \
  || { echo "FAIL: the testing core is not injected where it should be"; fail=1; }


exit $fail
