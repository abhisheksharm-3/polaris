# Design as a first-class flow: phases, the design core budget and injection, and design in build and review.
# covers: rules/flows.json rules/design-core.md hooks/inject-cores hooks/inject-standard hooks/hooks.json agents/*.md companions.json workflows/build.js workflows/review.js
source "$(dirname "$0")/../lib.sh"

# Design is first-class, so it is tested the way the code standard is. Until 2026-09-30 no flow had a
# design phase, "redesign the dashboard" routed nowhere, and the ui agent preloaded ~150 KB of five
# skills that disagreed, one of them under a personal-use license.

# The design flow runs direction before build and a critique after it, and the feature flow gives
# ux its own approved phase straight after the spec, before architecture.
jq -e '.design.phases | map(.name) == ["direction","build","critique","polish","gate"]' "${DIR}/../rules/flows.json" >/dev/null \
  && jq -e '.design.phases[0].approve == true' "${DIR}/../rules/flows.json" >/dev/null \
  && echo "ok: the design flow is direction, build, critique, polish, gate" \
  || { echo "FAIL: the design flow lost a phase or its direction approval"; fail=1; }
for f in feature foggy; do
  jq -e --arg f "$f" '.[$f].phases | map(.name) as $n | ($n | index("experience")) == (($n | index("spec")) + 1)' \
    "${DIR}/../rules/flows.json" >/dev/null \
    && jq -e --arg f "$f" '.[$f].phases[] | select(.name == "experience") | .run == "agent:ux" and .approve == true' \
      "${DIR}/../rules/flows.json" >/dev/null \
    || { echo "FAIL: the ${f} flow has no approved ux experience phase after spec"; fail=1; }
done
echo "ok: feature and foggy give ux an approved phase after the spec"
# The design core is injected every session by its own hook, inside its own budget, so it can never
# push core.md's payload past the cap.
dc_len="$(wc -c < "${DIR}/../rules/design-core.md" | tr -d ' ')"
[ "$dc_len" -le 3000 ] && echo "ok: rules/design-core.md is inside its 3000-byte budget (${dc_len})" \
  || { echo "FAIL: rules/design-core.md is ${dc_len} bytes, over its 3000-byte budget"; fail=1; }
jq -e '.hooks.SessionStart[].hooks[] | select(.command | test("inject-cores"))' "${DIR}/../hooks/hooks.json" >/dev/null \
  && echo '{}' | CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/inject-cores" \
    | jq -e '.hookSpecificOutput.additionalContext | test("DESIGN.md is the contract")' >/dev/null \
  && echo "ok: SessionStart injects the design core" \
  || { echo "FAIL: the design core is not injected at SessionStart"; fail=1; }
grep -q 'core design standard' <<<"$(is_ctx polaris:ui)" && grep -q 'comment law' <<<"$(is_ctx polaris:ui)" \
  && grep -q 'core design standard' <<<"$(is_ctx polaris:ux)" && ! grep -q 'comment law' <<<"$(is_ctx polaris:ux)" \
  && ! grep -q 'core design standard' <<<"$(is_ctx polaris:backend)" \
  && echo "ok: ui gets both standards, ux the design one, backend the code one" \
  || { echo "FAIL: inject-standard routes the design core to the wrong agents"; fail=1; }
# No agent preloads a design skill library: the standard is rules/design.md, companions load on
# demand. And nothing ships a skill whose license forbids commercial use.
grep -qE '^skills: frontend-design$' "${DIR}/../agents/ui.md" \
  && echo "ok: the ui agent preloads frontend-design only" \
  || { echo "FAIL: the ui agent preloads more than frontend-design"; fail=1; }
grep -rlq 'huashu-design' "${DIR}/../agents" "${DIR}/../companions.json" \
  && { echo "FAIL: a personal-use-licensed skill is named by an agent or companions.json"; fail=1; } \
  || echo "ok: no personal-use-licensed skill ships"
# The build and review workflows see design: a ui slice gets a ux critique, and review holds a design
# dimension that sits out a changeset with no UI file in it.
grep -q "agentType: 'polaris:ux'" "${DIR}/../workflows/build.js" && grep -q 'isVisual(slice)' "${DIR}/../workflows/build.js" \
  && echo "ok: a ui slice in the build gets a ux critique" \
  || { echo "FAIL: the build workflow does not critique ui slices"; fail=1; }
rv_ui="$(node -e '
const src = require("fs").readFileSync(process.argv[1], "utf8")
const m = src.match(/const UI_FILE = (\/.*\/[a-z]*)$/m)
if (!m) { process.stdout.write("no UI_FILE in review.js"); process.exit(0) }
const re = new Function("return " + m[1])()
const ui = "+++ b/src/api/handler.ts\n+x\n+++ b/src/Card.tsx\n+y"
const backend = "+++ b/src/api/handler.ts\n+x\n+++ b/db/schema.sql\n+y"
const ok = re.test(ui) && !re.test(backend)
process.stdout.write(ok ? "ok" : "wrong")
' "${DIR}/../workflows/review.js")"
[ "$rv_ui" = "ok" ] && echo "ok: review selects the design dimension for a ui diff and skips it for a backend one" \
  || { echo "FAIL: review's design gate is wrong ($rv_ui)"; fail=1; }

exit $fail
