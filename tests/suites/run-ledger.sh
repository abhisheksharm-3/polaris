# The run ledger: run-state seeds, records, hashes, approves, amends, and skips; check-flows and inventory resolve every target.
# covers: scripts/run-state.sh scripts/check-flows.sh scripts/inventory.sh hooks/guard-phase rules/flows.json agents/*.md commands/*.md workflows/*.js skills/*
source "$(dirname "$0")/../lib.sh"
GPHASE="${DIR}/../hooks/guard-phase"

# flows: every phase names a target that resolves, and a broken target is caught
FLOWCHECK="${DIR}/../scripts/check-flows.sh"
expect_exit 0 bash "$FLOWCHECK"
fc_tmp="$(mktemp -d)"
jq '.bug.phases[0].run = "agent:no-such-agent"' "${DIR}/../rules/flows.json" > "$fc_tmp/flows.json"
expect_exit 1 bash "$FLOWCHECK" "$fc_tmp/flows.json"
fc_out="$(bash "$FLOWCHECK" "$fc_tmp/flows.json" 2>&1 || true)"
grep -q 'no-such-agent' <<<"$fc_out" \
  && echo "ok: check-flows names the unresolved target" \
  || { echo "FAIL: check-flows did not name the unresolved target"; fail=1; }
jq '.bug.phases[0].run = "banana:thing"' "${DIR}/../rules/flows.json" > "$fc_tmp/kind.json"
expect_exit 1 bash "$FLOWCHECK" "$fc_tmp/kind.json"
rm -rf "$fc_tmp"

# run-state: the ledger refuses a phase that has not been earned
RS="${DIR}/../scripts/run-state.sh"
rs_tmp="$(mktemp -d)"
rs() { CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" "$@"; }
echo "a failing case at test/x.spec.ts:41" > "$rs_tmp/repro.md"

expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" seed bug demo
[ "$(rs get | jq -r .current)" = "reproduce" ] \
  && echo "ok: run-state seeds at the first phase" \
  || { echo "FAIL: run-state seeded at the wrong phase"; fail=1; }

# A later phase is refused, and the refusal names the phase actually owed.
rs_out="$(rs assert fix 2>&1 || true)"
grep -q 'reproduce' <<<"$rs_out" \
  && echo "ok: run-state names the phase still owed" \
  || { echo "FAIL: run-state did not name the owed phase ($rs_out)"; fail=1; }
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" assert fix

# Evidence is not optional: a phase whose flow declares evidence cannot be recorded without it.
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" record reproduce "$rs_tmp/absent.md" "nope"
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" record reproduce "$rs_tmp/repro.md" "test/x.spec.ts:41 fails"
[ "$(rs get | jq -r .record.reproduce.sha256 | wc -c)" -gt 32 ] \
  && echo "ok: run-state hashes the artifact it recorded" \
  || { echo "FAIL: run-state stored no hash"; fail=1; }
[ "$(rs get | jq -r .current)" = "rootcause" ] \
  && echo "ok: run-state advances a phase that needs no approval" \
  || { echo "FAIL: run-state did not advance"; fail=1; }

# An artifact edited after the fact invalidates the phase that claimed it.
echo "rewritten" > "$rs_tmp/repro.md"
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" assert rootcause
rs_out="$(rs assert rootcause 2>&1 || true)"
grep -qi 'changed' <<<"$rs_out" \
  && echo "ok: run-state catches an artifact edited after recording" \
  || { echo "FAIL: run-state missed a changed artifact ($rs_out)"; fail=1; }
echo "a failing case at test/x.spec.ts:41" > "$rs_tmp/repro.md"
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" assert rootcause

# An approval phase stops the run until a human stamps it.
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" record rootcause "$rs_tmp/repro.md" "the cause"
[ "$(rs get | jq -r .current)" = "rootcause" ] \
  && echo "ok: run-state holds at a phase awaiting approval" \
  || { echo "FAIL: run-state advanced past an unapproved phase"; fail=1; }
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" assert fix
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" approve rootcause
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" assert fix

# One open run per session, and clear ends it.
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" seed feature other
rs_out="$(rs seed feature other 2>&1 || true)"
grep -q 'demo' <<<"$rs_out" \
  && echo "ok: run-state names the run already open" \
  || { echo "FAIL: run-state did not name the open run ($rs_out)"; fail=1; }
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" clear
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" get
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" seed feature other

# A flow with no phases is not a run.
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" clear
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" seed conversation nope
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" bash "$RS" seed no-such-flow nope

# Two sessions are two conversations, so they hold two runs at once. This is the whole point of
# keying the pointer by session: one open run per session, never one per machine.
rsx() { env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION="$1" bash "$RS" "${@:2}"; }
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION=sess-a bash "$RS" seed bug para-a
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION=sess-b bash "$RS" seed feature para-b
[ "$(rsx sess-a get | jq -r .slug)" = "para-a" ] && [ "$(rsx sess-b get | jq -r .slug)" = "para-b" ] \
  && echo "ok: run-state holds two parallel runs, one per session" \
  || { echo "FAIL: parallel sessions did not each keep their own run"; fail=1; }

# The per-session limit still binds, and a slug another session owns is refused rather than shared.
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION=sess-a bash "$RS" seed feature para-a2
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION=sess-c bash "$RS" seed bug para-a

# Clearing one session leaves the other running.
expect_exit 0 env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION=sess-a bash "$RS" clear
expect_exit 1 env CLAUDE_PROJECT_DIR="$rs_tmp" POLARIS_SESSION=sess-a bash "$RS" get
[ "$(rsx sess-b get | jq -r .slug)" = "para-b" ] \
  && echo "ok: clearing one session does not touch another session's run" \
  || { echo "FAIL: clear reached across sessions"; fail=1; }

# A run opened before the pointer was per-session is adopted, not orphaned.
printf 'para-b' > "${rs_tmp}/.polaris/runs/.open"
[ "$(rsx sess-d get | jq -r .slug)" = "para-b" ] \
  && echo "ok: run-state adopts a run left at the pre-session pointer" \
  || { echo "FAIL: a legacy open run was not adopted"; fail=1; }
rm -rf "$rs_tmp"

# inventory: every dispatchable target, with a description the composer can choose from
INV="${DIR}/../scripts/inventory.sh"
inv_out="$(bash "$INV")"
[ "$(grep -c '^agent:' <<<"$inv_out")" -eq "$(ls "${DIR}/../agents"/*.md | wc -l | tr -d ' ')" ] \
  && echo "ok: inventory lists every fleet agent" \
  || { echo "FAIL: inventory missed an agent"; fail=1; }
grep -q '^inline\|^specialist' <<<"$inv_out" \
  && echo "ok: inventory lists the runtime targets" \
  || { echo "FAIL: inventory omitted inline and specialist"; fail=1; }
# A target with no description is one the composer cannot choose between.
[ "$(awk -F'\t' 'NF<2 || $2==""' <<<"$inv_out" | wc -l | tr -d ' ')" = 0 ] \
  && echo "ok: every inventory target carries a description" \
  || { echo "FAIL: an inventory target has no description"; fail=1; }
# Everything it prints must resolve, or the composer can pick a dead target in good faith.
inv_bad=0
while IFS=$'\t' read -r t _; do
  case "$t" in inline|specialist) continue ;; esac
  jq -n --arg t "$t" '{probe:{phases:[{name:"p",run:$t}]}}' > "${DIR}/.inv-probe.json"
  bash "${DIR}/../scripts/check-flows.sh" "${DIR}/.inv-probe.json" >/dev/null 2>&1 || inv_bad=$((inv_bad+1))
done <<<"$inv_out"
rm -f "${DIR}/.inv-probe.json"
[ "$inv_bad" = 0 ] && echo "ok: every inventory target resolves" \
  || { echo "FAIL: $inv_bad inventory targets do not resolve"; fail=1; }

# run-state: a composed flow is seeded, validated, and driven exactly like a named one
cs_tmp="$(mktemp -d)"; mkdir -p "$cs_tmp/.polaris"; echo '{}' > "$cs_tmp/.polaris/config.json"
cs() { CLAUDE_PROJECT_DIR="$cs_tmp" bash "$RS" "$@"; }
good='[{"name":"survey","run":"agent:researcher","evidence":"what exists"},{"name":"write","run":"agent:tech-writer"},{"name":"check","run":"command:gate"}]'
bad='[{"name":"survey","run":"agent:not-a-real-agent"}]'

echo "$bad" | cs seed --composed nope >/dev/null 2>&1 \
  && { echo "FAIL: a composed flow naming a missing agent was seeded"; fail=1; } \
  || echo "ok: a composed flow naming a missing target is refused"
[ -z "$(cs get 2>/dev/null)" ] && echo "ok: a refused composition opens no run" \
  || { echo "FAIL: a refused composition left a run open"; fail=1; }

echo "$good" | cs seed --composed docs-sweep >/dev/null
[ "$(cs get | jq -r .flow)" = "composed" ] && echo "ok: a composed run records that it was composed" \
  || { echo "FAIL: composed run not marked composed"; fail=1; }
[ "$(cs get | jq -r .current)" = "survey" ] && echo "ok: a composed run opens at its first phase" \
  || { echo "FAIL: composed run opened at the wrong phase"; fail=1; }
expect_exit 1 env CLAUDE_PROJECT_DIR="$cs_tmp" bash "$RS" assert write
echo "found" > "$cs_tmp/a.md"
expect_exit 0 env CLAUDE_PROJECT_DIR="$cs_tmp" bash "$RS" record survey "$cs_tmp/a.md" "three stale pages"
expect_exit 0 env CLAUDE_PROJECT_DIR="$cs_tmp" bash "$RS" assert write
[ "$(cs get | jq -r .current)" = "write" ] \
  && echo "ok: a composed run advances on its own phase list" \
  || { echo "FAIL: composed run did not advance"; fail=1; }

# The gate reads a composed phase the same way it reads a catalog one.
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"backend"}}' | CLAUDE_PROJECT_DIR="$cs_tmp" "$GPHASE" \
  | grep -q '"permissionDecision":"deny"' \
  && echo "ok: guard-phase gates a composed phase" \
  || { echo "FAIL: guard-phase ignored a composed phase"; fail=1; }

# A shape that keeps recurring is a catalog row waiting to be written, suggested and never written.
cs clear >/dev/null 2>&1
for i in 2 3; do echo "$good" | cs seed --composed "docs-sweep-$i" >/dev/null; cs clear >/dev/null 2>&1; done
echo "$good" | cs seed --composed docs-sweep-4 >/dev/null
cs_out="$(cs clear 2>&1 >/dev/null)"
grep -q 'flows.json' <<<"$cs_out" \
  && echo "ok: run-state suggests promoting a recurring composed shape" \
  || { echo "FAIL: no promotion suggestion after repeats ($cs_out)"; fail=1; }
rm -rf "$cs_tmp"

# amend: an approved artifact may change, and it may never change quietly. The hash is what lets a
# later phase and a cleared session trust the file over the conversation, so an amendment has to
# leave that trust intact by being recorded rather than by being forbidden.
am_tmp="$(mktemp -d)"; mkdir -p "$am_tmp/.polaris"; echo '{}' > "$am_tmp/.polaris/config.json"
am() { CLAUDE_PROJECT_DIR="$am_tmp" bash "${DIR}/../scripts/run-state.sh" "$@"; }
am seed feature amend-demo >/dev/null 2>&1
printf 'first\n' > "$am_tmp/spec.md"
am record spec "$am_tmp/spec.md" "the first draft" >/dev/null 2>&1
am approve spec >/dev/null 2>&1
am_before="$(jq -r '.record.spec.approvedAt' "$am_tmp/.polaris/runs/amend-demo/state.json")"
printf 'first\nsecond\n' > "$am_tmp/spec.md"
am assert experience >/dev/null 2>&1 \
  && { echo "FAIL: assert passed over an artifact edited after approval"; fail=1; } \
  || echo "ok: an edited artifact invalidates the phase that claimed it"
am amend spec "what the build found" >/dev/null 2>&1
am assert experience >/dev/null 2>&1 \
  && echo "ok: an amendment restores the phase it re-hashed" \
  || { echo "FAIL: assert still refuses after an amendment"; fail=1; }
[ "$(jq -r '.record.spec.approvedAt' "$am_tmp/.polaris/runs/amend-demo/state.json")" = "$am_before" ] \
  && echo "ok: an amendment keeps the approval it was given" \
  || { echo "FAIL: the amendment dropped or moved the approval"; fail=1; }
# The amendment must be legible later, or it is the silent edit it replaced.
[ "$(jq -r '.record.spec.amendments | length' "$am_tmp/.polaris/runs/amend-demo/state.json")" = "1" ] \
  && [ -n "$(jq -r '.record.spec.amendments[0].from' "$am_tmp/.polaris/runs/amend-demo/state.json")" ] \
  && [ -n "$(jq -r '.record.spec.amendedAt' "$am_tmp/.polaris/runs/amend-demo/state.json")" ] \
  && echo "ok: an amendment records the prior hash, the reason and the time" \
  || { echo "FAIL: the amendment left no legible trail"; fail=1; }
am amend spec "nothing actually changed" >/dev/null 2>&1 \
  && { echo "FAIL: amend accepted an unchanged artifact"; fail=1; } \
  || echo "ok: amend refuses an artifact that has not changed"
am amend spec >/dev/null 2>&1 \
  && { echo "FAIL: amend accepted an empty evidence string"; fail=1; } \
  || echo "ok: amend refuses an amendment with no evidence"
am amend ship "never recorded" >/dev/null 2>&1 \
  && { echo "FAIL: amend accepted a phase that was never recorded"; fail=1; } \
  || echo "ok: amend refuses a phase that was never recorded"
rm -f "$am_tmp/spec.md"
am amend spec "the artifact is gone" >/dev/null 2>&1 \
  && { echo "FAIL: amend accepted a missing artifact"; fail=1; } \
  || echo "ok: amend refuses an artifact that is gone"
rm -rf "$am_tmp"

# Conditional phases. A feature declares its surfaces in the spec and the ledger skips the phases
# for surfaces it does not touch. The break this guards: a backend change stopped for a ux approval,
# or worse, a change declaring `api` skipped its threat model.
cp_tmp="$(mktemp -d)"; mkdir -p "$cp_tmp/.polaris"; echo '{}' > "$cp_tmp/.polaris/config.json"
cph() { CLAUDE_PROJECT_DIR="$cp_tmp" CLAUDE_CODE_SESSION_ID=cp-test bash "${DIR}/../scripts/run-state.sh" "$@"; }
cph seed feature cp-api >/dev/null 2>&1
printf '# Orders API\n\nSurfaces: api\n' > "$cp_tmp/spec.md"
cph record spec "$cp_tmp/spec.md" "criteria" >/dev/null 2>&1; cph approve spec >/dev/null 2>&1
[ "$(cph get | jq -r .current)" = "contract" ] && [ "$(cph get | jq -r .record.experience.status)" = "skipped" ] \
  && echo "ok: an api-only feature skips ux and lands on the contract" \
  || { echo "FAIL: surfaces did not skip experience or reach contract ($(cph get | jq -c '{current,surfaces}'))"; fail=1; }
printf 'contract\n' > "$cp_tmp/contract.md"
cph record contract "$cp_tmp/contract.md" "endpoints" >/dev/null 2>&1; cph approve contract >/dev/null 2>&1
[ "$(cph get | jq -r .current)" = "threat-model" ] && [ "$(cph get | jq -r .record.schema.status)" = "skipped" ] \
  && echo "ok: an api feature skips the schema phase and still gets its threat model" \
  || { echo "FAIL: an api feature did not reach threat-model ($(cph get | jq -r .current))"; fail=1; }
printf 'threats\n' > "$cp_tmp/tm.md"; cph record threat-model "$cp_tmp/tm.md" "boundaries" >/dev/null 2>&1
cph assert design >/dev/null 2>&1 \
  && echo "ok: assert accepts skipped phases" || { echo "FAIL: assert refused over skipped phases"; fail=1; }
cph clear >/dev/null 2>&1
cph seed feature cp-none >/dev/null 2>&1
printf '# Untagged spec\n' > "$cp_tmp/spec2.md"
cph record spec "$cp_tmp/spec2.md" "criteria" >/dev/null 2>&1; cph approve spec >/dev/null 2>&1
[ "$(cph get | jq -r .current)" = "experience" ] \
  && echo "ok: a spec with no Surfaces line skips nothing" \
  || { echo "FAIL: an unclassified spec skipped phases ($(cph get | jq -r .current))"; fail=1; }
rm -rf "$cp_tmp"

# Surfaces are a contract: a typo is refused rather than silently skipping a threat model, and a spec
# amended after approval to add a surface re-opens the phase it had skipped, so later phases wait.
sf_proj="$(mktemp -d)"; mkdir -p "$sf_proj/.polaris"; echo '{}' > "$sf_proj/.polaris/config.json"
sf() { CLAUDE_PROJECT_DIR="$sf_proj" CLAUDE_CODE_SESSION_ID=sf bash "${DIR}/../scripts/run-state.sh" "$@"; }
sf seed feature sf-run >/dev/null 2>&1
printf 'Surfaces: ui, authh\n' > "$sf_proj/spec.md"
sf record spec "$sf_proj/spec.md" c >/dev/null 2>&1 && { echo "FAIL: a misspelled surface was accepted"; fail=1; }
printf 'Surfaces: ui\n' > "$sf_proj/spec.md"; sf record spec "$sf_proj/spec.md" c >/dev/null 2>&1
[ "$(sf get | jq -r .current)" = "spec" ] \
  || { echo "FAIL: recording the spec moved the run past its approval ($(sf get | jq -r .current))"; fail=1; }
sf approve spec >/dev/null 2>&1
echo x > "$sf_proj/ux.md"; sf record experience "$sf_proj/ux.md" e >/dev/null 2>&1; sf approve experience >/dev/null 2>&1
printf 'Surfaces: ui, auth\n' > "$sf_proj/spec.md"; sf amend spec "login added" >/dev/null 2>&1
[ "$(sf get | jq -r .current)" = "threat-model" ] && ! sf assert build >/dev/null 2>&1 \
  && echo "ok: surfaces refuse a typo, and an amended spec re-opens the threat model it skipped" \
  || { echo "FAIL: an amended spec did not re-open its skipped threat model ($(sf get | jq -c '{current,surfaces}'))"; fail=1; }
rm -rf "$sf_proj"

# A `when` outside the surface vocabulary would skip its phase on every run.
jq '.feature.phases[1].when = "uii"' "${DIR}/../rules/flows.json" > "${TMPDIR:-/tmp}/polaris-bad-flows.json"
bash "${DIR}/../scripts/check-flows.sh" "${TMPDIR:-/tmp}/polaris-bad-flows.json" >/dev/null 2>&1 \
  && { echo "FAIL: check-flows accepted a when token that is not a surface"; fail=1; } \
  || echo "ok: check-flows refuses a when token outside the surface vocabulary"
rm -f "${TMPDIR:-/tmp}/polaris-bad-flows.json"

exit $fail
