# The router: route-prompt classifies, enhance-prompt seeds the run it names, and nothing judges the prompt first.
# covers: hooks/enhance-prompt scripts/route-prompt.sh scripts/run-state.sh rules/patterns.json rules/flows.json hooks/hooks.json
source "$(dirname "$0")/../lib.sh"

# enhance-prompt: injects when enabled, silent when disabled
ENH="${DIR}/../hooks/enhance-prompt"
tmp_on="$(mktemp -d)"; mkdir -p "${tmp_on}/.polaris"; echo '{"promptEnhance":true}' > "${tmp_on}/.polaris/config.json"
tmp_off="$(mktemp -d)"; mkdir -p "${tmp_off}/.polaris"; echo '{"promptEnhance":false,"routing":false}' > "${tmp_off}/.polaris/config.json"
payload='{"prompt":"make the thing better"}'
if echo "$payload" | CLAUDE_PROJECT_DIR="$tmp_on"  "$ENH" | grep -q 'additionalContext'; then echo "ok: enhance injects when routing is on"; else echo "FAIL: enhance did not inject when routing is on"; fail=1; fi
if echo "$payload" | CLAUDE_PROJECT_DIR="$tmp_off" "$ENH" | grep -q 'additionalContext'; then echo "FAIL: enhance injected when routing is off"; fail=1; else echo "ok: enhance silent when routing is off"; fi
rm -rf "$tmp_on" "$tmp_off"

# No prompt-type gate on input. A veto that judges the prompt costs a model call on every turn and
# pays for itself only on an empty prompt, which the reply already catches. It false-stopped a real
# question on 2026-08-03; the turn it ate is the whole cost of the feature.
vetos="$(jq -r '[.hooks.UserPromptSubmit[].hooks[] | select(.type=="prompt")] | length' "${DIR}/../hooks/hooks.json")"
[ "$vetos" = 0 ] && echo "ok: no prompt-type veto stands between the user and the turn"   || { echo "FAIL: expected no prompt-type UserPromptSubmit hook, found $vetos"; fail=1; }
cmds="$(jq -r '[.hooks.UserPromptSubmit[].hooks[] | select(.type=="command")] | length' "${DIR}/../hooks/hooks.json")"
[ "$cmds" = 1 ] && echo "ok: the router is the only input hook"   || { echo "FAIL: the router command hook is missing"; fail=1; }

# route-prompt: every fixture prompt lands in its expected flow, conversation routes nowhere
ROUTE="${DIR}/../scripts/route-prompt.sh"
rp_bad=0
while IFS=$'\t' read -r want prompt; do
  [ -n "$want" ] || continue
  got="$(printf '%s' "$prompt" | bash "$ROUTE" 2>/dev/null || echo ERROR)"
  [ "$got" = "$want" ] || { echo "FAIL: route '$prompt' want $want got $got"; rp_bad=$((rp_bad+1)); fail=1; }
done < "${DIR}/fixtures/routing-cases.txt"
[ "$rp_bad" = 0 ] && echo "ok: every routing fixture lands in its flow" \
  || echo "FAIL: $rp_bad routing fixtures misrouted"

# enhance-prompt: a described task opens its run, a question opens nothing
EP_RS="${DIR}/../scripts/run-state.sh"
ep_proj() { local d; d="$(mktemp -d)"; mkdir -p "$d/.polaris"; echo "${1:-\{\}}" > "$d/.polaris/config.json"; echo "$d"; }
ep_run() { printf '%s' "$2" | jq -Rs '{prompt:.}' | CLAUDE_PROJECT_DIR="$1" "$ENH"; }
ep_state() { CLAUDE_PROJECT_DIR="$1" bash "$EP_RS" get 2>/dev/null; }

ep_bug="$(ep_proj '{}')"
ep_out="$(ep_run "$ep_bug" 'the referral code field accepts duplicates')"
grep -q 'additionalContext' <<<"$ep_out" && grep -q 'bug' <<<"$ep_out" \
  && echo "ok: enhance-prompt announces the flow it routed to" \
  || { echo "FAIL: enhance-prompt did not announce a flow ($ep_out)"; fail=1; }
[ "$(ep_state "$ep_bug" | jq -r .flow)" = "bug" ] \
  && echo "ok: enhance-prompt opens the run it announced" \
  || { echo "FAIL: enhance-prompt announced without opening a run"; fail=1; }
[ "$(ep_state "$ep_bug" | jq -r .current)" = "reproduce" ] \
  && echo "ok: enhance-prompt opens at the first phase" \
  || { echo "FAIL: enhance-prompt opened at the wrong phase"; fail=1; }

# A second prompt is input to the open run, never a second run.
ep_slug="$(ep_state "$ep_bug" | jq -r .slug)"
ep_out="$(ep_run "$ep_bug" 'add a referrals page with a share link')"
[ "$(ep_state "$ep_bug" | jq -r .slug)" = "$ep_slug" ] \
  && echo "ok: enhance-prompt leaves an open run alone" \
  || { echo "FAIL: enhance-prompt reseeded over an open run"; fail=1; }
grep -q 'reproduce' <<<"$ep_out" \
  && echo "ok: enhance-prompt names the phase the open run is on" \
  || { echo "FAIL: enhance-prompt did not name the open phase ($ep_out)"; fail=1; }

# A question is not work.
ep_q="$(ep_proj '{}')"
ep_out="$(ep_run "$ep_q" 'what does the stop-capture hook do')"
[ -z "$ep_out" ] && echo "ok: enhance-prompt stays silent on a question" \
  || { echo "FAIL: enhance-prompt routed a question ($ep_out)"; fail=1; }
[ -z "$(ep_state "$ep_q")" ] && echo "ok: enhance-prompt opens no run for a question" \
  || { echo "FAIL: enhance-prompt opened a run for a question"; fail=1; }

# Nothing matched: hand over the table, open nothing.
ep_u="$(ep_proj '{}')"
ep_out="$(ep_run "$ep_u" 'make it better')"
grep -q 'compose' <<<"$ep_out" \
  && echo "ok: enhance-prompt sends an unmatched task to the composer" \
  || { echo "FAIL: enhance-prompt did not offer composition ($ep_out)"; fail=1; }
[ -z "$(ep_state "$ep_u")" ] && echo "ok: enhance-prompt opens no run it cannot name" \
  || { echo "FAIL: enhance-prompt opened a run for an unknown class"; fail=1; }

# Turned off, and on a project that never ran setup.
ep_off="$(ep_proj '{"routing":false}')"
ep_out="$(ep_run "$ep_off" 'the referral code field accepts duplicates')"
[ -z "$(ep_state "$ep_off")" ] && echo "ok: enhance-prompt opens no run when routing is off" \
  || { echo "FAIL: enhance-prompt routed with routing off"; fail=1; }
ep_bare="$(mktemp -d)"
ep_out="$(ep_run "$ep_bare" 'the referral code field accepts duplicates')"
[ ! -d "$ep_bare/.polaris" ] \
  && echo "ok: enhance-prompt writes nothing into a project that never ran setup" \
  || { echo "FAIL: enhance-prompt created .polaris in a bare project"; fail=1; }
# AC3: a cleared session's first prompt gets the run, the phase, and the path to the last artifact.
# Without the path it would go looking for the approved spec, or guess, which is what makes the
# /clear recommendation in advance-flow safe to follow.
ep_rec="$(ep_proj '{}')"
CLAUDE_PROJECT_DIR="$ep_rec" bash "$EP_RS" seed feature ep-recover >/dev/null
echo "acceptance criteria" > "$ep_rec/spec.md"
CLAUDE_PROJECT_DIR="$ep_rec" bash "$EP_RS" record spec "$ep_rec/spec.md" "12 criteria" >/dev/null
CLAUDE_PROJECT_DIR="$ep_rec" bash "$EP_RS" approve spec >/dev/null
ep_out="$(ep_run "$ep_rec" 'carry on')"
grep -q 'ep-recover' <<<"$ep_out" && grep -q "phase 'experience'" <<<"$ep_out" \
  && echo "ok: enhance-prompt names the run and the phase after a clear" \
  || { echo "FAIL: enhance-prompt did not name run and phase ($ep_out)"; fail=1; }
grep -q 'spec.md' <<<"$ep_out" \
  && echo "ok: enhance-prompt names the artifact the recorded phase left" \
  || { echo "FAIL: enhance-prompt named no artifact ($ep_out)"; fail=1; }
rm "$ep_rec/spec.md"
ep_out="$(ep_run "$ep_rec" 'carry on')"
grep -q 'ep-recover' <<<"$ep_out" && ! grep -q 'spec.md' <<<"$ep_out" \
  && echo "ok: enhance-prompt names no artifact that is gone from disk" \
  || { echo "FAIL: enhance-prompt named a missing artifact ($ep_out)"; fail=1; }
rm -rf "$ep_rec"
rm -rf "$ep_bug" "$ep_q" "$ep_u" "$ep_off" "$ep_bare"

# --- T3: the router, measured rather than asserted ----------------------------------------------

# The classifier placed 9% of 800 real prompts from ~/.claude/history.jsonl on 2026-09-07, and the
# unknown branch then re-emitted the whole flow table on every one of them, including every
# follow-up in the same session. Two structural gaps, not pattern tuning: there was no ship class
# though agent:shipper existed only inside other flows, and the router assumed every prompt opens
# work when most are continuations.
RP="${DIR}/../scripts/route-prompt.sh"
rp() { printf '%s' "$1" | bash "$RP" 2>/dev/null; }

# ship, the most common developer instruction, used to route nowhere.
for c in \
  "commit and push all changes across backend and frontend" \
  "raise a pr from staging to main first" \
  "push the dashboard to this repo" \
  "commit this in scoped commits" ; do
  [ "$(rp "$c")" = "ship" ] && echo "ok: routed to ship: ${c:0:40}" \
    || { echo "FAIL: '${c:0:40}' routed to $(rp "$c"), not ship"; fail=1; }
done

# A bare follow-up opens nothing. This is the class that carried the waste.
for c in \
  "ok that was it, only ui changes?" \
  "now come back to our previous work" \
  "cool, do what is best and justified" \
  "try again" ; do
  [ "$(rp "$c")" = "continuation" ] && echo "ok: routed to continuation: ${c:0:36}" \
    || { echo "FAIL: '${c:0:36}' routed to $(rp "$c"), not continuation"; fail=1; }
done

# But a follow-up carrying real work must reach the real class, which is why continuation is tried
# last. Put first it swallowed these.
[ "$(rp "also push both backend and frontend to github once done")" = "ship" ] \
  && echo "ok: a follow-up carrying a ship still routes to ship" \
  || { echo "FAIL: continuation swallowed a ship instruction"; fail=1; }
# continuation is the last class tried, or it captures work that belongs elsewhere.
[ "$(jq -r '.routing[-1].class' "${DIR}/../rules/patterns.json")" = "continuation" ] \
  && echo "ok: continuation is the last class tried" \
  || { echo "FAIL: continuation is not last, so it will swallow real work"; fail=1; }

# A question opens nothing. `conversation` used to admit only a question whose second word was an
# auxiliary, so "what new feature can we introduce" matched the `feature` row on the words "new
# feature" and seeded a run with a spec phase. The label is enough here: the enhance-prompt block
# above proves a conversation opens no run.
for c in \
  "what new feature can we introduce in polaris, or what feature can we fix" \
  "what should we build next" \
  "should we build deck mode?" \
  "thoughts on the run ledger" ; do
  [ "$(rp "$c")" = "conversation" ] && echo "ok: routed to conversation: ${c:0:36}" \
    || { echo "FAIL: '${c:0:36}' routed to $(rp "$c"), not conversation"; fail=1; }
done

# Every class needs a flow and every flow a class, or one of them is unreachable.
rp_diff="$(comm -3 <(jq -r 'keys[]' "${DIR}/../rules/flows.json" | sort) \
                   <(jq -r '.routing[].class' "${DIR}/../rules/patterns.json" | sort))"
[ -z "$rp_diff" ] \
  && echo "ok: every routing class has a flow and every flow a class" \
  || { echo "FAIL: routing classes and flows disagree: ${rp_diff}"; fail=1; }

# The flow table goes out once per session. It was 895 bytes on every unrouted prompt, which is
# roughly 9,900 tokens across a forty-turn session for a menu already read.
ep_proj="$(mktemp -d)"; ep_tmp="$(mktemp -d)"
mkdir -p "$ep_proj/.polaris"; echo '{"routing":true}' > "$ep_proj/.polaris/config.json"
ep() { jq -cn --arg p "$1" '{prompt:$p}' | TMPDIR="$ep_tmp" CLAUDE_CODE_SESSION_ID=eptest \
  POLARIS_SESSION=eptest-none CLAUDE_PROJECT_DIR="$ep_proj" CLAUDE_PLUGIN_ROOT="${DIR}/.." \
  bash "${DIR}/../hooks/enhance-prompt" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null; }
ep1="$(ep "xyzzy frobnicate the plugh")"
ep2="$(ep "xyzzy frobnicate the plugh again differently")"
grep -q 'trivial:' <<<"$ep1" \
  && echo "ok: the first unrouted prompt gets the flow table" \
  || { echo "FAIL: the flow table was not emitted once"; fail=1; }
grep -q 'trivial:' <<<"$ep2" \
  && { echo "FAIL: the flow table was re-emitted in the same session"; fail=1; } \
  || echo "ok: the flow table is not repeated in the same session"
[ -n "$ep2" ] \
  && echo "ok: a later unrouted prompt still gets the short pointer" \
  || { echo "FAIL: a later unrouted prompt got nothing at all"; fail=1; }
# A continuation gets nothing, which is the point.
[ -z "$(ep "ok cool thanks")" ] \
  && echo "ok: a continuation injects nothing" \
  || { echo "FAIL: a continuation still injected context"; fail=1; }
rm -rf "$ep_proj" "$ep_tmp"

exit $fail
