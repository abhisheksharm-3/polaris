# The fleet: agent and command definitions validate, the model and effort floors hold, and every plugin path resolves.
# covers: agents/*.md commands/*.md scripts/check-agents.sh scripts/check-commands.sh hooks/* scripts/*.sh rules/model-floor.json rules/effort-floor.json
source "$(dirname "$0")/../lib.sh"
GPHASE="${DIR}/../hooks/guard-phase"

# agent frontmatter valid
expect_exit 0 bash "${DIR}/../scripts/check-agents.sh"

# flow.md references only real agents
expect_exit 0 bash "${DIR}/../scripts/check-commands.sh"

# the model floor: opus is a minimum on the judgment work, not a default a dispatch can undercut
MF_PROJ="$(mktemp -d)"; mkdir -p "$MF_PROJ/.polaris"; echo '{}' > "$MF_PROJ/.polaris/config.json"
mf() { jq -n --arg a "$1" --arg m "$2" '{tool_name:"Agent",tool_input:{subagent_type:$a,model:$m}}' \
  | CLAUDE_PROJECT_DIR="$MF_PROJ" "$GPHASE"; }
mf reviewer haiku | grep -q '"permissionDecision":"deny"' \
  && echo "ok: a reviewer dispatched below its floor is refused" \
  || { echo "FAIL: a reviewer ran on haiku"; fail=1; }
mf reviewer haiku | grep -q 'opus' \
  && echo "ok: the refusal names the floor" \
  || { echo "FAIL: the model refusal does not name the floor"; fail=1; }
[ -z "$(mf reviewer opus)" ] && echo "ok: a dispatch at the floor is allowed" \
  || { echo "FAIL: a dispatch at the floor was refused"; fail=1; }
[ -z "$(mf tech-writer sonnet)" ] && echo "ok: a dispatch at a sonnet floor is allowed" \
  || { echo "FAIL: a sonnet-floor dispatch was refused"; fail=1; }
# No explicit model means the agent's own frontmatter decides, which is already the policy.
[ -z "$(echo '{"tool_name":"Agent","tool_input":{"subagent_type":"reviewer"}}' | CLAUDE_PROJECT_DIR="$MF_PROJ" "$GPHASE")" ] \
  && echo "ok: a dispatch with no model is left to the agent's frontmatter" \
  || { echo "FAIL: a dispatch with no model was refused"; fail=1; }
# A model arrives as an alias, a full id, or `inherit`, and only the three aliases used to rank.
# Every other spelling ranked -1 and the `-ge 0` guard then skipped the check, so the floor was one
# argument away from off: `claude-haiku-4-5-20251001` passed an opus floor for the whole time the
# floor shipped, and the four assertions above never noticed because they only ever passed an alias.
for spelling in claude-haiku-4-5-20251001 claude-sonnet-5 fable; do
  mf "reviewer" "$spelling" | grep -q '"permissionDecision":"deny"' \
    && echo "ok: ${spelling} is refused below an opus floor" \
    || { echo "FAIL: ${spelling} passed an opus floor unranked"; fail=1; }
done
[ -z "$(mf reviewer claude-opus-5)" ] \
  && echo "ok: a full opus id is allowed at an opus floor" \
  || { echo "FAIL: claude-opus-5 was refused at an opus floor"; fail=1; }
# `inherit` takes the session's model, so it is not a downgrade the dispatch chose.
[ -z "$(mf reviewer inherit)" ] \
  && echo "ok: inherit is allowed, since it names no tier to undercut" \
  || { echo "FAIL: inherit was refused"; fail=1; }
# A model the table has never heard of cannot be ranked, and guessing is wrong in the one direction
# that matters, so it is refused rather than waved through.
mf "reviewer" "some-unreleased-model" | grep -q '"permissionDecision":"deny"' \
  && echo "ok: an unknown model is refused rather than passed unranked" \
  || { echo "FAIL: an unknown model passed the floor"; fail=1; }
# Every alias must map to a tier the ranking knows, or it resolves to nothing and passes.
mf_alias_bad="$(jq -r '.aliases | to_entries[] | select(.value as $v | ([$tiers[]] | index($v)) == null) | .key' \
  --argjson tiers "$(jq -c '.tiers' "${DIR}/../rules/model-floor.json")" \
  "${DIR}/../rules/model-floor.json" 2>/dev/null)"
[ -z "$mf_alias_bad" ] \
  && echo "ok: every model alias maps to a known tier" \
  || { echo "FAIL: aliases map to unknown tiers: ${mf_alias_bad}"; fail=1; }

# Every floor must name a real agent, or the table quietly protects nothing.
mf_bad=""
for a in $(jq -r '.floor | keys[]' "${DIR}/../rules/model-floor.json"); do
  [ -f "${DIR}/../agents/${a}.md" ] || mf_bad="${mf_bad} ${a}"
done
[ -z "$mf_bad" ] && echo "ok: every model floor names a real agent" \
  || { echo "FAIL: model floors for agents that do not exist:${mf_bad}"; fail=1; }

# The effort floor is enforced in frontmatter by check-agents.sh, not at dispatch, since 2026-09-07:
# the Agent tool has no effort parameter, so a dispatch gate on it refused nothing. check-agents.sh
# passing on the real fleet (above) holds every agent at or over its floor; this proves it fails on a
# violation, or the frontmatter is decoration.
ef_probe="$(mktemp -d)"; mkdir -p "${ef_probe}/agents" "${ef_probe}/rules"
cp "${DIR}/../rules/effort-floor.json" "${DIR}/../rules/model-floor.json" "${ef_probe}/rules/"
sed 's/^effort: high$/effort: low/' "${DIR}/../agents/reviewer.md" > "${ef_probe}/agents/reviewer.md"
# Capture, then grep. `set -o pipefail` is on at the top of this file, so piping a command that
# exits non-zero into `grep -q` yields the command's status, not grep's, and the && branch never
# runs even when the match is there. check-agents.sh exits 1 by design when it finds a violation,
# which is exactly the case this assertion is checking for.
ef_probe_out="$(CLAUDE_PLUGIN_ROOT="$ef_probe" bash "${DIR}/../scripts/check-agents.sh" 2>&1 || true)"
printf '%s' "$ef_probe_out" | grep -q 'below the floor' \
  && echo "ok: check-agents.sh fails an agent thinking below its floor" \
  || { echo "FAIL: check-agents.sh passed an agent below its effort floor"; fail=1; }
rm -rf "$ef_probe"

# The levels list has to span what the harness accepts, or a floor can never require the top of it.
jq -e '.levels == ["low","medium","high","xhigh","max"]' "${DIR}/../rules/effort-floor.json" >/dev/null \
  && echo "ok: the effort levels span the documented range" \
  || { echo "FAIL: rules/effort-floor.json does not list every effort level"; fail=1; }
# The two floors must cover the same agents, or one of them silently protects a subset.
diff <(jq -r '.floor|keys[]' "${DIR}/../rules/model-floor.json" | sort) \
     <(jq -r '.floor|keys[]' "${DIR}/../rules/effort-floor.json" | sort) >/dev/null 2>&1 \
  && echo "ok: the effort floor and the model floor cover the same agents" \
  || { echo "FAIL: the effort and model floors name different agents"; fail=1; }
rm -rf "$MF_PROJ"

for ref in $(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[a-zA-Z0-9/._-]+' \
    "${DIR}/../commands"/*.md "${DIR}/../scripts"/*.sh "${DIR}/../hooks"/* 2>/dev/null \
    | sed 's|\${CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
  [ -e "${DIR}/../${ref}" ] \
    || { echo "FAIL: polaris names ${ref}, which is not in that plugin"; fail=1; }
done
echo "ok: every path polaris names resolves inside polaris"

exit $fail
