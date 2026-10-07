# The polaris-work plugin: journal, sweep, 1:1, and OKR scripts, its hooks and off switch, and what it mirrors from polaris.
# covers: plugins/polaris-work/* rules/connectors.md commands/catchup.md scripts/worktracker-snapshot.sh scripts/check-patterns.sh rules/patterns.json
source "$(dirname "$0")/../lib.sh"

# journal-facts: buckets a day's activity by project, excludes other days.
#
# POLARIS_HISTORY_FILE is set on every call below. Without it these read the developer's own
# ~/.claude/history.jsonl, which is how the asks assertions came to pass against real prompts and a
# day with no fixture transcript reported real project names.
JF="${WORK}/scripts/journal-facts.sh"
jf_out="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" POLARIS_HISTORY_FILE="${DIR}/fixtures/journal/history.jsonl" bash "$JF" 2026-07-14)"
echo "$jf_out" | grep -q '## demo'              && echo "ok: journal project section" || { echo "FAIL: journal project section"; fail=1; }
echo "$jf_out" | grep -q 'Sessions: 2'          && echo "ok: journal session count"    || { echo "FAIL: journal session count"; fail=1; }
echo "$jf_out" | grep -q 'add the login form'   && echo "ok: journal ask captured"      || { echo "FAIL: journal ask captured"; fail=1; }
echo "$jf_out" | grep -q 'fix the checkout bug' && echo "ok: journal second ask"        || { echo "FAIL: journal second ask"; fail=1; }
if echo "$jf_out" | grep -q 'OTHER DAY'; then echo "FAIL: journal leaked another day"; fail=1; else echo "ok: journal excludes other days"; fi

# journal-facts: memory written that day is reported, so the journal covers what was learned, not
# only what was committed. mtime is set here because git does not preserve it.
jf_mem="${DIR}/fixtures/journal/projects/-Users-test-Projects-demo/memory/fixture-note.md"
touch -t 202607141200 "$jf_mem"
jf_out2="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" POLARIS_HISTORY_FILE="${DIR}/fixtures/journal/history.jsonl" bash "$JF" 2026-07-14)"
echo "$jf_out2" | grep -q 'fixture-note.md' && echo "ok: journal reports memory written that day" || { echo "FAIL: journal missed memory writes"; fail=1; }
touch -t 202607201200 "$jf_mem"
jf_out3="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" POLARIS_HISTORY_FILE="${DIR}/fixtures/journal/history.jsonl" bash "$JF" 2026-07-14)"
if echo "$jf_out3" | grep -q 'fixture-note.md'; then echo "FAIL: journal reported memory from another day"; fail=1; else echo "ok: journal memory is date-scoped"; fi

# journal-facts: a day with no session but a memory write is still a day with a record. Guards the
# early exit, which used to gate the whole file on transcripts and drop every other source. 2026-07-10
# has no fixture transcript, so only the memory write can produce output.
touch -t 202607101200 "$jf_mem"
jf_out4="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" POLARIS_HISTORY_FILE="${DIR}/fixtures/journal/history.jsonl" bash "$JF" 2026-07-10)"
echo "$jf_out4" | grep -q 'fixture-note.md' && echo "ok: journal reports a session-less day" || { echo "FAIL: journal dropped a day with no session"; fail=1; }
echo "$jf_out4" | grep -q 'projects: \[\]' && echo "ok: journal frontmatter empty project list" || { echo "FAIL: journal frontmatter wrong for a session-less day"; fail=1; }
touch -t 202607141200 "$jf_mem"

# journal-facts: a day with nothing anywhere stays silent, so no empty journal file is written.
jf_out5="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" HOME="$(mktemp -d)" bash "$JF" 2026-07-09)"
if [ -n "$jf_out5" ]; then echo "FAIL: journal emitted for a day with no activity"; fail=1; else echo "ok: journal silent on an empty day"; fi

# journal-facts: the session-start hook must not pay for GitHub network calls; /journal may.
jf_bin="$(mktemp -d)"; jf_calls="${jf_bin}/calls"
printf '#!/bin/sh\necho "$@" >> "%s"\n[ "$1" = auth ] && exit 0\nexit 0\n' "$jf_calls" > "$jf_bin/gh"; chmod +x "$jf_bin/gh"
POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" PATH="$jf_bin:$PATH" bash "$JF" 2026-07-14 hook >/dev/null 2>&1
if [ -s "$jf_calls" ]; then echo "FAIL: journal-facts called gh on the hook path"; fail=1; else echo "ok: journal-facts skips gh for the hook"; fi
POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" PATH="$jf_bin:$PATH" bash "$JF" 2026-07-14 /journal >/dev/null 2>&1
grep -q 'search prs' "$jf_calls" && echo "ok: journal-facts queries GitHub for /journal" || { echo "FAIL: journal-facts skipped GitHub for /journal"; fail=1; }
rm -rf "$jf_bin"

# every command that reads connectors follows the shared rule, so the Slack thread fix cannot drift
for c in catchup; do
  grep -q 'rules/connectors.md' "${DIR}/../commands/${c}.md" \
    && echo "ok: ${c} cites the connectors rule" || { echo "FAIL: ${c} does not cite rules/connectors.md"; fail=1; }
done
for c in journal sweep; do
  grep -q 'rules/connectors.md' "${WORK}/commands/${c}.md" \
    && echo "ok: ${c} cites the connectors rule" || { echo "FAIL: ${c} does not cite rules/connectors.md"; fail=1; }
done

# connectors.md exists in both plugins because both read connectors and neither can reference the
# other's files. A mirrored file drifts unless something fails when it does.
cmp -s "${DIR}/../rules/connectors.md" "${WORK}/rules/connectors.md" \
  && echo "ok: the connectors rule is identical in both plugins" \
  || { echo "FAIL: rules/connectors.md has drifted between polaris and polaris-work"; fail=1; }

# sweep-window: window resolution, first-run fallback, and lookback cap
SW="${WORK}/scripts/sweep-window.sh"
sw_state="$(mktemp)"
echo '{"lastRunAt":"2026-07-20T03:30:00Z"}' > "$sw_state"
sw1="$(bash "$SW" --now 2026-07-20T12:30:00Z --state "$sw_state" --max-lookback-hours 168)"
echo "$sw1" | jq -e '.start=="2026-07-20T03:30:00Z" and .firstRun==false and .capped==false' >/dev/null \
  && echo "ok: sweep-window normal span" || { echo "FAIL: sweep-window normal span ($sw1)"; fail=1; }
sw2="$(bash "$SW" --now 2026-07-20T12:00:00Z --state /nonexistent-state --max-lookback-hours 168)"
echo "$sw2" | jq -e '.firstRun==true and .start=="2026-07-19T12:00:00Z"' >/dev/null \
  && echo "ok: sweep-window first-run 24h fallback" || { echo "FAIL: sweep-window first-run ($sw2)"; fail=1; }
echo '{"lastRunAt":"2026-07-01T00:00:00Z"}' > "$sw_state"
sw3="$(bash "$SW" --now 2026-07-20T00:00:00Z --state "$sw_state" --max-lookback-hours 168)"
echo "$sw3" | jq -e '.capped==true and .start=="2026-07-13T00:00:00Z" and .trueGapHours==456' >/dev/null \
  && echo "ok: sweep-window cap at maxLookback" || { echo "FAIL: sweep-window cap ($sw3)"; fail=1; }
echo '{"lastRunAt":"2026-07-25T00:00:00Z"}' > "$sw_state"
sw4="$(bash "$SW" --now 2026-07-20T00:00:00Z --state "$sw_state" --max-lookback-hours 168)"
echo "$sw4" | jq -e '.firstRun==true and .start=="2026-07-19T00:00:00Z"' >/dev/null \
  && echo "ok: sweep-window future lastRunAt falls back to first-run" || { echo "FAIL: sweep-window future lastRunAt ($sw4)"; fail=1; }
echo '{"lastRunAt":"not-a-date"}' > "$sw_state"
sw5="$(bash "$SW" --now 2026-07-20T00:00:00Z --state "$sw_state" --max-lookback-hours 168)"
echo "$sw5" | jq -e '.firstRun==true' >/dev/null \
  && echo "ok: sweep-window malformed lastRunAt falls back to first-run" || { echo "FAIL: sweep-window malformed lastRunAt ($sw5)"; fail=1; }
sw6="$(bash "$SW" --now 2026-08-03T00:00:00Z --state /nonexistent-state --first-run-hours 336 --max-lookback-hours 504)"
echo "$sw6" | jq -e '.firstRun==true and .start=="2026-07-20T00:00:00Z" and .trueGapHours==336' >/dev/null \
  && echo "ok: sweep-window first-run-hours widens the first window" || { echo "FAIL: sweep-window first-run-hours ($sw6)"; fail=1; }
sw8="$(bash "$SW" --now 2026-08-03T00:00:00Z --state /nonexistent-state --first-run-hours 1000 --max-lookback-hours 168)"
echo "$sw8" | jq -e '.start=="2026-07-27T00:00:00Z" and .trueGapHours==168' >/dev/null \
  && echo "ok: sweep-window clamps first-run-hours to the cap" || { echo "FAIL: sweep-window first-run clamp ($sw8)"; fail=1; }
rm -f "$sw_state"

# oneonone-join: the structural 1:1 test, the forward bracket, and the claiming pass
OJ="${WORK}/scripts/oneonone-join.sh"
oj_ev="${DIR}/fixtures/oneonone-events.json"
oj_mt="${DIR}/fixtures/oneonone-meetings.json"
oj_pair='[.[] | select(.recording_id==166154353 or .recording_id==166058462)]'
oj1="$(bash "$OJ" series --self self@example.com < "$oj_ev")"
echo "$oj1" | jq -e '.status=="ok" and .manager.email=="manager@example.com"' >/dev/null \
  && echo "ok: oneonone-join derives the manager from the two-attendee series" || { echo "FAIL: oneonone-join series ($oj1)"; fail=1; }
echo "$oj1" | jq -e '.instances[0].createdAfter==.instances[0].start' >/dev/null \
  && echo "ok: oneonone-join brackets forward from the event start" || { echo "FAIL: oneonone-join bracket start"; fail=1; }
echo "$oj1" | jq -e '(.instances[0].createdBefore|fromdateiso8601) - (.instances[0].end|fromdateiso8601) == 10800' >/dev/null \
  && echo "ok: oneonone-join applies L as three hours by default" || { echo "FAIL: oneonone-join default L"; fail=1; }
oj2="$(bash "$OJ" series --self self@example.com --lag-hours 12 < "$oj_ev")"
echo "$oj2" | jq -e '(.instances[0].createdBefore|fromdateiso8601) - (.instances[0].end|fromdateiso8601) == 43200 and .instances[0].createdAfter==.instances[0].start' >/dev/null \
  && echo "ok: oneonone-join lag-hours moves only the far edge" || { echo "FAIL: oneonone-join lag-hours"; fail=1; }
echo "$oj1" | jq -e '[.otherTitles[] | select(test("1:1"))] | length == 0' >/dev/null \
  && echo "ok: oneonone-join keeps the series title out of otherTitles" || { echo "FAIL: oneonone-join otherTitles"; fail=1; }
echo "$oj1" | jq -e '.instances[0].start | test("Z$")' >/dev/null \
  && echo "ok: oneonone-join emits UTC despite a +05:30 calendar offset" || { echo "FAIL: oneonone-join offset normalisation"; fail=1; }
[ "$(bash "$OJ" widen --lag-hours 3)" = 12 ] && [ "$(bash "$OJ" widen --lag-hours 5)" = 20 ] \
  && echo "ok: oneonone-join derives the widening probe from L" || { echo "FAIL: oneonone-join widen"; fail=1; }
oj3="$(jq -c "$oj_pair" "$oj_mt" | bash "$OJ" claim --attendees manager@example.com,self@example.com)"
echo "$oj3" | jq -e '.status=="resolved" and .recordingId==166058462 and .labeled==false and .tier=="B"' >/dev/null \
  && echo "ok: oneonone-join resolves the unlabeled in-person recording" || { echo "FAIL: oneonone-join claim ($oj3)"; fail=1; }
oj4="$(jq -c "$oj_pair"' | [.[] | if .recording_id==166058462 then .calendar_invitees=[{email:"manager@example.com"},{email:"self@example.com"}] else . end]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com)"
echo "$oj4" | jq -e '.status=="resolved" and .recordingId==166058462 and .labeled==true and .tier=="A"' >/dev/null \
  && echo "ok: oneonone-join claims a remote 1:1 by exact invitee match" || { echo "FAIL: oneonone-join tier A ($oj4)"; fail=1; }
printf 'Client Sync\nTeam Stand Up\n' > "${DIR}/oj-titles.tmp"
oj5="$(jq -c "$oj_pair"' | [.[] | if .recording_id==166058462 then .title="Client Sync" else . end]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com --titles "${DIR}/oj-titles.tmp")"
echo "$oj5" | jq -e '.status=="none"' >/dev/null \
  && echo "ok: oneonone-join drops a candidate another event explains" || { echo "FAIL: oneonone-join title claim ($oj5)"; fail=1; }
rm -f "${DIR}/oj-titles.tmp"
oj6="$(jq -c '[.[] | select((.calendar_invitees // []) | length == 0)]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com)"
echo "$oj6" | jq -e '.status=="ambiguous" and .default==(.candidates[0].recordingId) and (.candidates | length) > 1' >/dev/null \
  && echo "ok: oneonone-join refuses to pick among unclaimed candidates" || { echo "FAIL: oneonone-join ambiguous ($oj6)"; fail=1; }
oj7="$(echo '[]' | bash "$OJ" claim --attendees a@b.c,d@e.f --created-after 2026-07-22T10:30:00Z --created-before 2026-07-22T14:00:00Z)"
echo "$oj7" | jq -e '.status=="none" and .bracket.createdBefore=="2026-07-22T14:00:00Z"' >/dev/null \
  && echo "ok: oneonone-join names the bracket it searched" || { echo "FAIL: oneonone-join empty bracket ($oj7)"; fail=1; }
oj8="$(jq -c "$oj_pair" "$oj_mt" | bash "$OJ" claim --attendees manager@example.com,self@example.com --created-after 2026-07-22T10:30:00Z)"
echo "$oj8" | jq -e 'has("lagMinutes") and .lagMinutes==null' >/dev/null \
  && echo "ok: oneonone-join reports a null lag because list_meetings omits created" || { echo "FAIL: oneonone-join lagMinutes ($oj8)"; fail=1; }
oj9="$(jq -c "$oj_pair"' | [.[] | if .recording_id==166058462 then .created="2026-07-22T11:17:00Z" else . end]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com --created-after 2026-07-22T10:30:00Z)"
echo "$oj9" | jq -e '.lagMinutes==47' >/dev/null \
  && echo "ok: oneonone-join measures the ingest lag when created is present" || { echo "FAIL: oneonone-join lag arithmetic ($oj9)"; fail=1; }

# oneonone-inbox: capture, read, and consume, against an isolated HOME
OI="${WORK}/scripts/oneonone-inbox.sh"
oi_home="$(mktemp -d)"
oi() { HOME="$oi_home" bash "$OI" "$@"; }
oi_file="$oi_home/.claude/polaris-memory/oneonone/inbox.md"
oi_out="$(oi add --date 2026-08-03 ask about the promotion rubric)"
[ -f "$oi_file" ] && grep -qxF -- '- [ ] 2026-08-03 · ask about the promotion rubric' "$oi_file" \
  && echo "ok: oneonone-inbox add creates the file and the item" || { echo "FAIL: oneonone-inbox add"; fail=1; }
grep -q 'inbox.md' <<<"$oi_out" && grep -q '1' <<<"$oi_out" \
  && echo "ok: oneonone-inbox add names the file and the count" || { echo "FAIL: oneonone-inbox add report ($oi_out)"; fail=1; }
oi_first="$(head -1 "$oi_file")"
oi add --date 2026-08-04 second thing >/dev/null
[ "$(head -1 "$oi_file")" = "$oi_first" ] && [ "$(grep -c '^- \[ \]' "$oi_file")" = 2 ] \
  && echo "ok: oneonone-inbox appends without rewriting" || { echo "FAIL: oneonone-inbox append"; fail=1; }
oi_before="$(cat "$oi_file")"
oi add >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox refuses an empty add" || { echo "FAIL: oneonone-inbox empty add (rc=$oi_rc)"; fail=1; }
oi add --date 2026-08-04 "$(printf 'multi\nline thought')" >/dev/null
[ "$(grep -c '^- \[ \]' "$oi_file")" = 3 ] && [ "$(wc -l < "$oi_file" | tr -d ' ')" = 3 ] \
  && echo "ok: oneonone-inbox collapses a newline into one line" || { echo "FAIL: oneonone-inbox newline"; fail=1; }
printf -- '- [x] 2026-07-01 · old thing · raised 2026-07-15\n' >> "$oi_file"
[ "$(oi list | wc -l | tr -d ' ')" = 3 ] \
  && echo "ok: oneonone-inbox list skips consumed items" || { echo "FAIL: oneonone-inbox list"; fail=1; }
oi list | head -1 | grep -q "^1	2026-08-03	ask about the promotion rubric$" \
  && echo "ok: oneonone-inbox list numbers open items as tsv" || { echo "FAIL: oneonone-inbox list shape"; fail=1; }
printf 'not an item at all\n' >> "$oi_file"
oi_err="$(oi list 2>&1 >/dev/null)"; oi_rc=$?
[ "$oi_rc" = 0 ] && grep -q 'does not parse' <<<"$oi_err" \
  && echo "ok: oneonone-inbox names an unparsable line and keeps going" || { echo "FAIL: oneonone-inbox unparsable ($oi_err)"; fail=1; }
oi consume --date 2026-08-05 1 3 >/dev/null
[ "$(grep -c '^- \[x\].*raised 2026-08-05' "$oi_file")" = 2 ] && [ "$(grep -c '^- \[ \]' "$oi_file")" = 1 ] \
  && echo "ok: oneonone-inbox consumes exactly the named items" || { echo "FAIL: oneonone-inbox consume"; fail=1; }
oi_before="$(cat "$oi_file")"
oi consume --date 2026-08-05 1 2 3 4 5 6 >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox refuses more than five per agenda" || { echo "FAIL: oneonone-inbox cap (rc=$oi_rc)"; fail=1; }
oi consume --date 2026-08-05 99 >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox refuses an out-of-range item" || { echo "FAIL: oneonone-inbox range (rc=$oi_rc)"; fail=1; }
oi_out="$(HOME=/nonexistent-home bash "$OI" list 2>&1)"; oi_rc=$?
[ "$oi_rc" = 0 ] && [ -z "$(HOME=/nonexistent-home bash "$OI" list 2>/dev/null)" ] \
  && echo "ok: oneonone-inbox list on a missing inbox is empty, not an error" || { echo "FAIL: oneonone-inbox missing ($oi_out)"; fail=1; }
oi consume --date 2026-08-05 1 >/dev/null
oi restore --date 2026-08-05 >/dev/null
[ "$(grep -c '^- \[x\]' "$oi_file")" = 1 ] && [ "$(grep -c 'raised 2026-08-05' "$oi_file")" = 0 ] \
  && echo "ok: oneonone-inbox restore reopens that date's items only" || { echo "FAIL: oneonone-inbox restore"; fail=1; }
oi_before="$(cat "$oi_file")"
oi restore --date 2026-01-01 >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox restore refuses a date it never consumed" || { echo "FAIL: oneonone-inbox restore date (rc=$oi_rc)"; fail=1; }
rm -rf "$oi_home"

# okr-pace: behind, ahead, on-track, flag, and near-zero-elapsed
OP="${WORK}/scripts/okr-pace.sh"
op_prog="$(mktemp)"
cat > "$op_prog" <<'JSON'
{ "periodStart": "2026-04-01",
  "krs": [
    { "id": "O2-KR1", "metric": "problem statements", "current": 3, "target": 6, "deadline": "2026-09-30", "committed": true },
    { "id": "O1-KR1", "metric": "clean prod launch", "current": 0, "target": 1, "deadline": "2026-09-30", "committed": true, "kind": "flag" },
    { "id": "O3-KR1", "metric": "reusable things", "current": 4, "target": 5, "deadline": "2026-09-30", "committed": true },
    { "id": "O4-KR1", "metric": "ownership areas", "current": 0, "target": 4, "deadline": "2026-09-30", "committed": true }
  ] }
JSON
op1="$(bash "$OP" --now 2026-07-28 --progress "$op_prog")"
echo "$op1" | jq -e '.[] | select(.id=="O2-KR1") | .status=="behind" and .needToCatch==1' >/dev/null \
  && echo "ok: okr-pace behind names catch-up" || { echo "FAIL: okr-pace behind ($op1)"; fail=1; }
echo "$op1" | jq -e '.[] | select(.id=="O1-KR1") | .status=="flag" and .done==false' >/dev/null \
  && echo "ok: okr-pace flag KR not paced" || { echo "FAIL: okr-pace flag ($op1)"; fail=1; }
echo "$op1" | jq -e '.[] | select(.id=="O3-KR1") | .status=="ahead"' >/dev/null \
  && echo "ok: okr-pace ahead" || { echo "FAIL: okr-pace ahead ($op1)"; fail=1; }
op2="$(bash "$OP" --now 2026-04-02 --progress "$op_prog")"
echo "$op2" | jq -e '.[] | select(.id=="O4-KR1") | .status=="on-track"' >/dev/null \
  && echo "ok: okr-pace near-zero elapsed is on-track" || { echo "FAIL: okr-pace near-zero ($op2)"; fail=1; }
op_bad=$(bash "$OP" --now 2026-07-28 --progress /nonexistent 2>/dev/null; echo "exit:$?")
echo "$op_bad" | grep -q 'exit:2' \
  && echo "ok: okr-pace missing progress exits 2" || { echo "FAIL: okr-pace missing progress ($op_bad)"; fail=1; }
rm -f "$op_prog"

# --- the split left two dangling cross-plugin references ----------------------------------------

# /oneonone called worktracker-snapshot.sh and check-patterns.sh through ${CLAUDE_PLUGIN_ROOT},
# which after the split resolves to polaris-work, where neither existed. Two plugins ship
# independently, so neither can reach the other's files, and a path that resolves to nothing fails
# only when a user runs the command.
for ref in $(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[a-zA-Z0-9/._-]+' \
    "${WORK}"/commands/*.md "${WORK}"/scripts/*.sh "${WORK}"/hooks/* 2>/dev/null \
    | sed 's|\${CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
  [ -e "${WORK}/${ref}" ] \
    || { echo "FAIL: polaris-work names ${ref}, which is not in that plugin"; fail=1; }
done
echo "ok: every path polaris-work names resolves inside polaris-work"

# worktracker-snapshot.sh is mirrored rather than shared, so it drifts unless something fails.
cmp -s "${DIR}/../scripts/worktracker-snapshot.sh" "${WORK}/scripts/worktracker-snapshot.sh" \
  && echo "ok: worktracker-snapshot.sh is identical in both plugins" \
  || { echo "FAIL: worktracker-snapshot.sh has drifted between the plugins"; fail=1; }

# polaris-work carries the eight injection phrases rather than all of patterns.json, because that
# file also holds prose, code and routing classes it has no use for. The list still has to match.
si_repo="$(jq -r '.injection.phrases[]' "${DIR}/../rules/patterns.json" | sort)"
si_work="$(sed -n '/^phrases=(/,/^)/p' "${WORK}/scripts/screen-injection.sh" \
  | sed '1d;$d' | sed -E 's/^[[:space:]]*"//; s/"$//' | sed 's/\\"/"/g' | sort)"
[ "$si_repo" = "$si_work" ] \
  && echo "ok: polaris-work screens the same injection phrases as patterns.json" \
  || { echo "FAIL: the injection phrase lists have drifted between the plugins"; fail=1; }
# It must agree with check-patterns on the fixtures, or it is a screen in name only.
bash "${CHECK}" injection "${DIR}/fixtures/injection-bad.txt" >/dev/null 2>&1; si_a=$?
bash "${WORK}/scripts/screen-injection.sh" "${DIR}/fixtures/injection-bad.txt" >/dev/null 2>&1; si_b=$?
[ "$si_a" = "$si_b" ] && [ "$si_b" = 1 ] \
  && echo "ok: screen-injection flags what check-patterns flags" \
  || { echo "FAIL: screen-injection disagrees on a flagged fixture (${si_a} vs ${si_b})"; fail=1; }
bash "${WORK}/scripts/screen-injection.sh" "${DIR}/fixtures/injection-clean.txt" >/dev/null 2>&1 \
  && echo "ok: screen-injection passes a clean fixture" \
  || { echo "FAIL: screen-injection flagged a clean fixture"; fail=1; }

# --- polaris-work: an off switch, a wider journal, and a reaper ----------------------------------

# Its Stop hook had no gate at all. It keys on ~/.claude/polaris-memory/journal, which is user-level
# and says nothing about the project, so installing this plugin blocked a turn in every repo the user
# opened: a client's checkout, someone else's clone, a throwaway. The root plugin's hooks all
# early-exit without .polaris/config.json and this one had no equivalent, which is backwards for the
# half that is about the user rather than the code.
WSC="${WORK}/hooks/stop-capture"
wg_home="$(mktemp -d)"; wg_tmp="$(mktemp -d)"
wg_stranger="$(mktemp -d)"; wg_polaris="$(mktemp -d)"; mkdir -p "$wg_polaris/.polaris"
mkdir -p "$wg_home/.claude/polaris-memory/journal"
printf -- '---\nstatus: facts\n---\n' > "$wg_home/.claude/polaris-memory/journal/$(date +%F).md"
wg() { # $1 project, $2 config json or "none"
  if [ "$2" = "none" ]; then rm -f "$wg_home/.claude/polaris-memory/work-config.json"
  else printf '%s' "$2" > "$wg_home/.claude/polaris-memory/work-config.json"; fi
  rm -rf "$wg_tmp/polaris-work-journal" 2>/dev/null
  # A silent hook emits nothing at all, and jq on empty input also emits nothing, so the two have to
  # be told apart before the comparison rather than after it.
  local out
  out="$(printf '%s' '{"stop_hook_active":false,"session_id":"wg1"}' | HOME="$wg_home" TMPDIR="$wg_tmp" \
    CLAUDE_PLUGIN_ROOT="$WORK" CLAUDE_PROJECT_DIR="$1" bash "$WSC" 2>/dev/null)"
  if [ -z "$out" ]; then echo silent
  elif printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1; then echo asks
  else echo silent; fi
}
[ "$(wg "$wg_stranger" none)" = "silent" ] \
  && echo "ok: polaris-work stays quiet in a project that never opted in" \
  || { echo "FAIL: polaris-work blocks a turn in any repo, opted in or not"; fail=1; }
[ "$(wg "$wg_polaris" none)" = "asks" ] \
  && echo "ok: polaris-work asks in a project with .polaris/" \
  || { echo "FAIL: polaris-work went silent where it should ask"; fail=1; }
[ "$(wg "$wg_polaris" '{"enabled":false}')" = "silent" ] \
  && echo "ok: enabled false silences polaris-work entirely" \
  || { echo "FAIL: enabled false did not silence the Stop hook"; fail=1; }
[ "$(wg "$wg_stranger" '{"askIn":"any"}')" = "asks" ] \
  && echo "ok: askIn any restores the old reach when asked for" \
  || { echo "FAIL: askIn any did not widen the ask"; fail=1; }
[ "$(wg "$wg_polaris" '{"askIn":"never"}')" = "silent" ] \
  && echo "ok: askIn never silences the ask and leaves the backfill" \
  || { echo "FAIL: askIn never still asked"; fail=1; }
# An explicit allowlist is the user naming exactly where, so it beats askIn in both directions.
[ "$(wg "$wg_stranger" "$(jq -cn --arg p "$wg_stranger" '{askIn:"polaris",projects:[$p]}')")" = "asks" ] \
  && echo "ok: an allowlisted project is asked even without .polaris/" \
  || { echo "FAIL: the projects allowlist did not admit a project"; fail=1; }
[ "$(wg "$wg_polaris" "$(jq -cn --arg p "$wg_stranger" '{askIn:"any",projects:[$p]}')")" = "silent" ] \
  && echo "ok: a non-empty allowlist excludes everything outside it" \
  || { echo "FAIL: the projects allowlist did not exclude a project"; fail=1; }
# session-start honours the kill switch too, or the plugin is only half off.
rm -f "$wg_home/.claude/polaris-memory/work-config.json"
rm -rf "$wg_home/.claude/polaris-memory/journal"
printf '%s' '{"enabled":false}' > "$wg_home/.claude/polaris-memory/work-config.json"
HOME="$wg_home" CLAUDE_PLUGIN_ROOT="$WORK" bash "${WORK}/hooks/session-start" >/dev/null 2>&1
[ ! -d "$wg_home/.claude/polaris-memory/journal" ] \
  && echo "ok: enabled false stops the session-start backfill as well" \
  || { echo "FAIL: session-start wrote a journal with the plugin disabled"; fail=1; }
rm -rf "$wg_home" "$wg_tmp" "$wg_stranger" "$wg_polaris"

# The journal reads typed prompts from history.jsonl, not from the transcripts.
#
# Transcripts carry every user-role turn, so hook context and a workflow agent's own prompt read as
# the user's question, and they are pruned: on 2026-09-07 they reached 2026-07-24 while
# history.jsonl held 15,946 prompts from 2026-03-12. Four of six months were unreadable by the
# command whose job is writing days up.
JF="${WORK}/scripts/journal-facts.sh"
jf_home="$(mktemp -d)"; jf_proj="$(mktemp -d)"; jf_work="$(mktemp -d)"
mkdir -p "$jf_home/.claude" "$jf_proj/-Users-x-demo"
# One typed prompt, and one transcript row that is NOT a typed prompt.
jf_ms="$(jq -rn '((("2026-09-07T12:00:00Z") | fromdateiso8601) * 1000) | floor')"
jq -cn --arg p "$jf_work" --argjson t "$jf_ms" \
  '{display:"the question the user actually typed",project:$p,sessionId:"s1",timestamp:$t}' \
  > "$jf_home/.claude/history.jsonl"
printf '%s\n' "$(jq -cn --arg c "$jf_work" '{timestamp:"2026-09-07T01:00:00Z",cwd:$c,sessionId:"s1",message:{role:"user",content:"Review this change for security vulnerabilities."}}')" \
  > "$jf_proj/-Users-x-demo/s1.jsonl"
jf_out="$(POLARIS_JOURNAL_PROJECTS_DIR="$jf_proj" POLARIS_HISTORY_FILE="$jf_home/.claude/history.jsonl" \
  HOME="$jf_home" bash "$JF" 2026-09-07 journal 2>/dev/null)"
grep -q 'the question the user actually typed' <<<"$jf_out" \
  && echo "ok: the journal reports the typed prompt" \
  || { echo "FAIL: the journal did not read history.jsonl"; fail=1; }
grep -q 'Review this change for security' <<<"$jf_out" \
  && { echo "FAIL: the journal still reports injected transcript text as a question"; fail=1; } \
  || echo "ok: the journal ignores a transcript turn the user never typed"
# A day with no transcript at all still has its prompts, which is the four months it could not reach.
rm -rf "$jf_proj"; mkdir -p "$jf_proj"
jf_old="$(POLARIS_JOURNAL_PROJECTS_DIR="$jf_proj" POLARIS_HISTORY_FILE="$jf_home/.claude/history.jsonl" \
  HOME="$jf_home" bash "$JF" 2026-09-07 journal 2>/dev/null)"
grep -q 'the question the user actually typed' <<<"$jf_old" \
  && echo "ok: a day with no surviving transcript still gets a record" \
  || { echo "FAIL: a pruned-transcript day reports nothing"; fail=1; }
grep -q 'Sessions: 0' <<<"$jf_old" \
  && { echo "FAIL: a pruned-transcript day reports Sessions: 0, which reads as no work"; fail=1; } \
  || echo "ok: a zero session count is omitted rather than printed"
rm -rf "$jf_home" "$jf_proj" "$jf_work"

# /standup, and the SessionEnd reaper.
grep -q 'journal-facts.sh' "${WORK}/commands/standup.md" \
  && echo "ok: /standup reads the facts extractor rather than guessing" \
  || { echo "FAIL: /standup does not use journal-facts.sh"; fail=1; }
jq -e '.hooks.SessionEnd | length > 0' "${WORK}/hooks/hooks.json" >/dev/null \
  && echo "ok: polaris-work reaps its marker on SessionEnd" \
  || { echo "FAIL: polaris-work leaves its block marker behind"; fail=1; }
we_tmp="$(mktemp -d)"; mkdir -p "$we_tmp/polaris-work-journal/mine" "$we_tmp/polaris-work-journal/theirs"
printf '%s' '{"session_id":"mine"}' | TMPDIR="$we_tmp" bash "${WORK}/hooks/session-end" >/dev/null 2>&1
[ ! -d "$we_tmp/polaris-work-journal/mine" ] && [ -d "$we_tmp/polaris-work-journal/theirs" ] \
  && echo "ok: the reaper clears its own marker and leaves another session's" \
  || { echo "FAIL: the reaper cleared the wrong marker"; fail=1; }
rm -rf "$we_tmp"

exit $fail
