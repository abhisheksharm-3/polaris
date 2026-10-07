# The flow gates: guard-phase, guard-command, advance-flow, and session-end hold a run to its phases.
# covers: hooks/guard-phase hooks/guard-command hooks/advance-flow hooks/session-end hooks/hooks.json scripts/run-state.sh scripts/review-level.sh rules/flows.json rules/model-floor.json
source "$(dirname "$0")/../lib.sh"
RS="${DIR}/../scripts/run-state.sh"
EP_RS="$RS"

# guard-phase: a dispatch the current phase does not name is refused
GPHASE="${DIR}/../hooks/guard-phase"
gp_proj="$(mktemp -d)"; mkdir -p "$gp_proj/.polaris"; echo '{}' > "$gp_proj/.polaris/config.json"
gp_task() { jq -n --arg t "${2:-Task}" --arg a "$1" '{tool_name:$t,tool_input:{subagent_type:$a}}'; }
gp_run() { echo "$1" | CLAUDE_PROJECT_DIR="$gp_proj" "$GPHASE"; }

# No run open: the gate has no opinion.
gp_run "$(gp_task backend)" | grep -q 'deny' \
  && { echo "FAIL: guard-phase denied with no run open"; fail=1; } \
  || echo "ok: guard-phase allows any dispatch with no run open"

CLAUDE_PROJECT_DIR="$gp_proj" bash "$EP_RS" seed feature demo >/dev/null
gp_out="$(gp_run "$(gp_task backend)")"
grep -q '"permissionDecision":"deny"' <<<"$gp_out" \
  && echo "ok: guard-phase refuses a builder during spec" \
  || { echo "FAIL: guard-phase let a builder run during spec"; fail=1; }
grep -q 'spec' <<<"$gp_out" \
  && echo "ok: guard-phase names the phase it refused against" \
  || { echo "FAIL: guard-phase refused without naming the phase ($gp_out)"; fail=1; }
gp_run "$(gp_task product)" | grep -q 'deny' \
  && { echo "FAIL: guard-phase denied the agent its own phase names"; fail=1; } \
  || echo "ok: guard-phase allows the agent the phase names"
gp_run "$(gp_task polaris:product)" | grep -q 'deny' \
  && { echo "FAIL: guard-phase denied a namespaced agent name"; fail=1; } \
  || echo "ok: guard-phase accepts a namespaced agent name"

# A phase that names a command or a workflow is not an agent gate; those phases dispatch freely.
CLAUDE_PROJECT_DIR="$gp_proj" bash "$EP_RS" clear >/dev/null
CLAUDE_PROJECT_DIR="$gp_proj" bash "$EP_RS" seed audit demo2 >/dev/null
gp_run "$(gp_task reviewer)" | grep -q 'deny' \
  && { echo "FAIL: guard-phase gated a phase that names a command"; fail=1; } \
  || echo "ok: guard-phase leaves a command phase ungated"
# The dispatch tool is named Agent in current versions and Task in older ones, and the field
# naming the agent has moved with it. A gate reading the wrong name allows everything in silence.
CLAUDE_PROJECT_DIR="$gp_proj" bash "$EP_RS" clear >/dev/null
CLAUDE_PROJECT_DIR="$gp_proj" bash "$EP_RS" seed feature demo3 >/dev/null
gp_run "$(gp_task backend Agent)" | grep -q '"permissionDecision":"deny"' \
  && echo "ok: guard-phase gates a dispatch named Agent" \
  || { echo "FAIL: guard-phase ignored the Agent tool name"; fail=1; }
echo '{"tool_name":"Agent","tool_input":{"agent_type":"backend"}}' | CLAUDE_PROJECT_DIR="$gp_proj" "$GPHASE" \
  | grep -q '"permissionDecision":"deny"' \
  && echo "ok: guard-phase reads agent_type as well as subagent_type" \
  || { echo "FAIL: guard-phase missed the agent_type field"; fail=1; }
jq -r '.hooks.PreToolUse[].matcher' "${DIR}/../hooks/hooks.json" | grep -q 'Agent' \
  && echo "ok: the PreToolUse matcher admits the Agent tool" \
  || { echo "FAIL: the PreToolUse matcher does not admit Agent"; fail=1; }
rm -rf "$gp_proj"

# advance-flow: the Stop hook drives the run and blocks once per transition
ADV="${DIR}/../hooks/advance-flow"
av_proj="$(mktemp -d)"; mkdir -p "$av_proj/.polaris"; echo '{}' > "$av_proj/.polaris/config.json"
av_tmp="$(mktemp -d)"
av_run() { jq -n --arg s "${2:-s1}" '{stop_hook_active:false,session_id:$s}' \
  | TMPDIR="$av_tmp" CLAUDE_PROJECT_DIR="$av_proj" "$ADV"; }
av_state() { CLAUDE_PROJECT_DIR="$av_proj" bash "$EP_RS" "$@"; }

[ -z "$(av_run)" ] && echo "ok: advance-flow is silent with no run open" \
  || { echo "FAIL: advance-flow blocked with no run open"; fail=1; }

av_state seed bug demo >/dev/null
av_out="$(av_run '' s1)"
grep -q '"decision":"block"' <<<"$av_out" \
  && echo "ok: advance-flow blocks a turn ending mid-phase" \
  || { echo "FAIL: advance-flow let a turn end mid-phase"; fail=1; }
grep -q 'reproduce' <<<"$av_out" \
  && echo "ok: advance-flow names the phase still owed" \
  || { echo "FAIL: advance-flow did not name the owed phase"; fail=1; }
[ -z "$(av_run '' s1)" ] && echo "ok: advance-flow blocks once per transition" \
  || { echo "FAIL: advance-flow blocked twice for the same phase"; fail=1; }

# AC6: nothing is recorded yet, so there is no artifact for a cleared session to read and no
# recommendation to make. This is the state a clear would actually cost work in.
! grep -q '/clear' <<<"$av_out" \
  && echo "ok: advance-flow recommends no clear before anything is recorded" \
  || { echo "FAIL: advance-flow recommended a clear over unrecorded work"; fail=1; }

# A recorded phase that stops for a human asks for the approval, not the next phase.
echo "repro" > "$av_proj/repro.md"
av_state record reproduce "$av_proj/repro.md" "a failing case" >/dev/null
av_out="$(av_run '' s1)"
grep -q 'rootcause' <<<"$av_out" \
  && echo "ok: advance-flow asks for the next phase once one is recorded" \
  || { echo "FAIL: advance-flow did not name the next phase ($av_out)"; fail=1; }

# The widened gate: 'reproduce' declares no approve in rules/flows.json, and its artifact is recorded
# and hash-matching, so the boundary is safe to clear. Gating on an approved predecessor would have
# skipped this boundary and the 40 others like it, including the one after 'build' in the feature
# flow, which is the most expensive phase Polaris runs.
grep -q '/clear' <<<"$av_out" \
  && echo "ok: advance-flow recommends a clear past a recorded phase that needs no approval" \
  || { echo "FAIL: advance-flow recommended no clear past an unapproved boundary ($av_out)"; fail=1; }
av_state record rootcause "$av_proj/repro.md" "the cause" >/dev/null
av_out="$(av_run '' s1)"
grep -qi 'approv' <<<"$av_out" \
  && echo "ok: advance-flow asks for the approval a phase stops on" \
  || { echo "FAIL: advance-flow skipped an approval ($av_out)"; fail=1; }

# The documented loop-breaker, and a finished flow.
[ -z "$(jq -n '{stop_hook_active:true,session_id:"s1"}' | TMPDIR="$av_tmp" CLAUDE_PROJECT_DIR="$av_proj" "$ADV")" ] \
  && echo "ok: advance-flow honors stop_hook_active" \
  || { echo "FAIL: advance-flow ignored stop_hook_active"; fail=1; }
# AC7: done and awaiting a human is the one branch that must stay quiet. The artifact exists, but the
# phase has not been presented yet, and a clear would take the presentation with it.
! grep -q '/clear' <<<"$av_out" \
  && echo "ok: advance-flow recommends no clear while an approval is owed" \
  || { echo "FAIL: advance-flow recommended a clear before an approval"; fail=1; }

# AC5: past an approval, the conversation holds nothing the ledger does not, and the hook says so
# with both the slug and the path, because a clear that loses the path costs more than it saves.
av_state approve rootcause >/dev/null
av_out="$(av_run '' s2)"
grep -q '/clear' <<<"$av_out" \
  && echo "ok: advance-flow recommends a clear past an approval" \
  || { echo "FAIL: advance-flow recommended no clear past an approval ($av_out)"; fail=1; }
grep -q 'demo' <<<"$av_out" && grep -q 'repro.md' <<<"$av_out" \
  && echo "ok: the clear recommendation names the run and the artifact" \
  || { echo "FAIL: the clear recommendation named no run or artifact ($av_out)"; fail=1; }

# AC8: the artifact is the thing that replaces the conversation. Gone from disk, the recommendation
# must not fire, whatever the ledger claims about the phase.
mv "$av_proj/repro.md" "$av_proj/repro.moved"
av_out="$(av_run '' s3)"
grep -q '"decision":"block"' <<<"$av_out" && ! grep -q '/clear' <<<"$av_out" \
  && echo "ok: advance-flow recommends no clear when the recorded artifact is gone" \
  || { echo "FAIL: advance-flow recommended a clear over a missing artifact ($av_out)"; fail=1; }
mv "$av_proj/repro.moved" "$av_proj/repro.md"
echo "edited after recording" >> "$av_proj/repro.md"
av_out="$(av_run '' s4)"
! grep -q '/clear' <<<"$av_out" \
  && echo "ok: advance-flow recommends no clear when a recorded artifact changed" \
  || { echo "FAIL: advance-flow recommended a clear over a changed artifact ($av_out)"; fail=1; }
rm -rf "$av_proj" "$av_tmp"

# guard-command: typing a later phase's command skips every phase before it
GCMD="${DIR}/../hooks/guard-command"
gc_proj="$(mktemp -d)"; mkdir -p "$gc_proj/.polaris"; echo '{}' > "$gc_proj/.polaris/config.json"
gc() { jq -n --arg n "$1" --arg d "$gc_proj" '{command_name:$n,cwd:$d}' | "$GCMD"; }

[ -z "$(gc polaris:release)" ] && echo "ok: guard-command is silent with no run open" \
  || { echo "FAIL: guard-command blocked with no run open"; fail=1; }

CLAUDE_PROJECT_DIR="$gc_proj" bash "$RS" seed release cut-1 >/dev/null
gc_out="$(gc polaris:release)"
grep -q '"decision":"block"' <<<"$gc_out" \
  && echo "ok: guard-command refuses a later phase command" \
  || { echo "FAIL: guard-command allowed a skipped phase ($gc_out)"; fail=1; }
grep -q 'gate' <<<"$gc_out" \
  && echo "ok: guard-command names the phase still owed" \
  || { echo "FAIL: guard-command did not name the owed phase"; fail=1; }
[ -z "$(gc polaris:gate)" ] && echo "ok: guard-command allows the phase the run is on" \
  || { echo "FAIL: guard-command blocked the current phase"; fail=1; }
[ -z "$(gc polaris:catchup)" ] && echo "ok: guard-command ignores a command outside the flow" \
  || { echo "FAIL: guard-command blocked unrelated work"; fail=1; }
[ -z "$(gc polaris:pause)" ] && echo "ok: guard-command never blocks the escape hatch" \
  || { echo "FAIL: guard-command blocked /polaris:pause"; fail=1; }
rm -rf "$gc_proj"
jq -e '.hooks.UserPromptExpansion | length > 0' "${DIR}/../hooks/hooks.json" >/dev/null \
  && echo "ok: guard-command is registered on UserPromptExpansion" \
  || { echo "FAIL: guard-command is not registered"; fail=1; }

# --- T4: the wiring that existed and was not connected -------------------------------------------

# advance-flow names the review level. The three workflows read args.level to pick 2, 8, 14 or 28
# agents, scripts/review-level.sh computes it, and nothing joined them until 2026-09-07, so every
# run took the widest default and the four-level matrix was dead configuration.
af_proj="$(mktemp -d)"; mkdir -p "$af_proj/.polaris"; echo '{"routing":true}' > "$af_proj/.polaris/config.json"
( cd "$af_proj" && git init -q . && printf 'a\nb\nc\n' > f.ts && git add -A \
  && git -c user.email=t@t -c user.name=t commit -qm "test: seed" ) >/dev/null 2>&1
printf 'a\nb\nc\nd\n' > "$af_proj/f.ts"
POLARIS_SESSION=aftest CLAUDE_PROJECT_DIR="$af_proj" bash "${DIR}/../scripts/run-state.sh" seed review af-probe >/dev/null 2>&1
af_tmp="$(mktemp -d)"
af_out="$(jq -cn '{session_id:"aftest",stop_hook_active:false}' \
  | TMPDIR="$af_tmp" POLARIS_SESSION=aftest CLAUDE_PROJECT_DIR="$af_proj" CLAUDE_PLUGIN_ROOT="${DIR}/.." \
    bash "${DIR}/../hooks/advance-flow" | jq -r '.reason' 2>/dev/null)"
grep -qE "args.level = \"(low|mid|high)\"" <<<"$af_out" \
  && echo "ok: the level it names is one review.js accepts" \
  || { echo "FAIL: advance-flow named a level the workflow does not accept"; fail=1; }
# A non-workflow phase must not carry the hint, or it becomes noise on every turn.
POLARIS_SESSION=aftest CLAUDE_PROJECT_DIR="$af_proj" bash "${DIR}/../scripts/run-state.sh" clear >/dev/null 2>&1
POLARIS_SESSION=aftest2 CLAUDE_PROJECT_DIR="$af_proj" bash "${DIR}/../scripts/run-state.sh" seed cleanup af-probe2 >/dev/null 2>&1
af_out2="$(jq -cn '{session_id:"aftest2",stop_hook_active:false}' \
  | TMPDIR="$af_tmp" POLARIS_SESSION=aftest2 CLAUDE_PROJECT_DIR="$af_proj" CLAUDE_PLUGIN_ROOT="${DIR}/.." \
    bash "${DIR}/../hooks/advance-flow" | jq -r '.reason' 2>/dev/null)"
grep -q 'args.level' <<<"$af_out2" \
  && { echo "FAIL: advance-flow named a level on an agent phase"; fail=1; } \
  || echo "ok: advance-flow names no level on a non-workflow phase"

# clear archives the ledger instead of deleting it. rm -rf destroyed every phase record, hash,
# approval and amendment at the moment the run became a complete history of itself.
POLARIS_SESSION=aftest2 CLAUDE_PROJECT_DIR="$af_proj" bash "${DIR}/../scripts/run-state.sh" clear >/dev/null 2>&1
[ -f "$af_proj/.polaris/runs/.done/af-probe2/state.json" ] \
  && echo "ok: clear archives the ledger under .done" \
  || { echo "FAIL: clear destroyed the run ledger"; fail=1; }
[ ! -d "$af_proj/.polaris/runs/af-probe2" ] \
  && echo "ok: clear frees the active run directory" \
  || { echo "FAIL: clear left the run in place"; fail=1; }
# A reused slug must not overwrite the archive.
POLARIS_SESSION=aftest3 CLAUDE_PROJECT_DIR="$af_proj" bash "${DIR}/../scripts/run-state.sh" seed cleanup af-probe2 >/dev/null 2>&1
POLARIS_SESSION=aftest3 CLAUDE_PROJECT_DIR="$af_proj" bash "${DIR}/../scripts/run-state.sh" clear >/dev/null 2>&1
[ -d "$af_proj/.polaris/runs/.done/af-probe2-2" ] \
  && echo "ok: a reused slug is suffixed rather than overwriting its archive" \
  || { echo "FAIL: a second run of the same slug overwrote the archive"; fail=1; }
rm -rf "$af_proj" "$af_tmp"

# session-end reaps the pointer CLAUDE.md documented as never reaped, and keeps the ledger.
se_proj="$(mktemp -d)"; se_tmp="$(mktemp -d)"
mkdir -p "$se_proj/.polaris/runs/stale" "$se_tmp/polaris-advance-flow/reap1-stale-x-open"
echo 'stale' > "$se_proj/.polaris/runs/.open-reap1"
echo '{"slug":"stale","flow":"review","current":"review","record":{}}' > "$se_proj/.polaris/runs/stale/state.json"
jq -cn '{session_id:"reap1"}' | TMPDIR="$se_tmp" CLAUDE_PROJECT_DIR="$se_proj" \
  CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/session-end" >/dev/null 2>&1
[ ! -f "$se_proj/.polaris/runs/.open-reap1" ] \
  && echo "ok: session-end reaps the run pointer" \
  || { echo "FAIL: session-end left the pointer behind"; fail=1; }
[ -f "$se_proj/.polaris/runs/.done/stale/state.json" ] \
  && echo "ok: session-end archives the run rather than discarding it" \
  || { echo "FAIL: session-end lost the ledger of an abandoned run"; fail=1; }
[ ! -d "$se_tmp/polaris-advance-flow/reap1-stale-x-open" ] \
  && echo "ok: session-end clears this session's block markers" \
  || { echo "FAIL: session-end left block markers behind"; fail=1; }
# Another session's pointer is none of its business.
echo 'other' > "$se_proj/.polaris/runs/.open-someone-else"
jq -cn '{session_id:"reap1"}' | TMPDIR="$se_tmp" CLAUDE_PROJECT_DIR="$se_proj" \
  CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/session-end" >/dev/null 2>&1
[ -f "$se_proj/.polaris/runs/.open-someone-else" ] \
  && echo "ok: session-end leaves another session's pointer alone" \
  || { echo "FAIL: session-end reaped a pointer it does not own"; fail=1; }
jq -e '.hooks.SessionEnd | length > 0' "${DIR}/../hooks/hooks.json" >/dev/null \
  && echo "ok: session-end is registered on SessionEnd" \
  || { echo "FAIL: session-end is not wired"; fail=1; }
rm -rf "$se_proj" "$se_tmp"

# The reaper drops a run that records nothing, so a misroute stops nagging. It must never read as
# permission to skip a flow that was right: the archive is stamped abandoned, and the message sends
# real work back into a flow instead of saying carry on.
rp_proj="$(mktemp -d)"; mkdir -p "$rp_proj/.polaris"; echo '{}' > "$rp_proj/.polaris/config.json"; rp_tmp="$(mktemp -d)"
CLAUDE_PROJECT_DIR="$rp_proj" CLAUDE_CODE_SESSION_ID=rp bash "$EP_RS" seed feature rp-run >/dev/null 2>&1
rp_out=""
for _ in 1 2 3; do
  rp_out="$(jq -n '{stop_hook_active:false,session_id:"rp"}' | TMPDIR="$rp_tmp" CLAUDE_PROJECT_DIR="$rp_proj" CLAUDE_CODE_SESSION_ID=rp "$ADV")"
done
rp_arch="$(ls -d "$rp_proj"/.polaris/runs/.done/rp-run* 2>/dev/null | head -1)"
[ -n "$rp_arch" ] && jq -e '.abandoned.reason' "$rp_arch/state.json" >/dev/null 2>&1 \
  && grep -q 'reopen it in the right one' <<<"$rp_out" && ! grep -q 'Nothing else to do' <<<"$rp_out" \
  && echo "ok: a reaped run is stamped abandoned and real work is sent back to a flow" \
  || { echo "FAIL: the reaper dropped a run without stamping it or without sending work back to a flow ($rp_out)"; fail=1; }
rm -rf "$rp_proj" "$rp_tmp"

exit $fail
