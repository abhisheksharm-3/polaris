# Session injection: session-start fits the hook cap and injects the right slice, inject-standard reaches writers, companions install once.
# covers: hooks/session-start hooks/inject-standard scripts/tracker-slice.sh scripts/ensure-companions.sh scripts/check-patterns.sh scripts/route-prompt.sh rules/*.md rules/stacks/* rules/stack-map.json rules/patterns.json commands/*.md
source "$(dirname "$0")/../lib.sh"

# inject-standard: the comment law reaches a writer subagent, and non-code agents are left alone
INJECT="${DIR}/../hooks/inject-standard"
echo '{"agent_type":"backend"}' | "$INJECT" | grep -q 'No inline comments' \
  && echo "ok: inject-standard carries the comment law to a writer" || { echo "FAIL: inject-standard missed the writer"; fail=1; }
if echo '{"agent_type":"product"}' | "$INJECT" | grep -q 'additionalContext'; then echo "FAIL: inject-standard fired for a non-code agent"; fail=1; else echo "ok: inject-standard skips non-code agents"; fi

# regression: session-start survives an empty detected-stacks array (bash 3.2 under set -u); RCA 2026-07-16
SS="${DIR}/../hooks/session-start"
ss_home="$(mktemp -d)"; ss_cwd="$(mktemp -d)"
mkdir -p "$ss_home/.claude/skills"; touch "$ss_home/.claude/skills/.polaris-mindrally-synced" "$ss_home/.claude/skills/.polaris-companions-installed"
ss_start=$(date +%s)
( cd "$ss_cwd" && echo '{}' | HOME="$ss_home" bash "$SS" >/dev/null 2>&1 ); ss_rc=$?
ss_dur=$(( $(date +%s) - ss_start ))
[ "$ss_rc" -eq 0 ] && echo "ok: session-start exits 0 with no detected stack" || { echo "FAIL: session-start crashed with no stack (exit $ss_rc)"; fail=1; }
[ "$ss_dur" -lt 10 ] && echo "ok: session-start completes under 10s" || { echo "FAIL: session-start took ${ss_dur}s (startup perf regression)"; fail=1; }
rm -rf "$ss_home" "$ss_cwd"

# The payload has to fit in the 10,000-character hook cap. Over it, Claude Code writes the whole
# thing to a file and hands the model a 2KB preview plus the path, with exit 0 and no error, so the
# standard silently stops arriving. That was the state from the first release until 2026-09-07, at
# 62,985 characters, and no assertion here caught it: the block above checks exit code and duration,
# and the ones below check content, none of which fail on a payload that never reaches the model.
#
# Measured against a populated tracker and memory index, because both are variable and both are what
# pushed the real payload over. 9,000 is the assertion rather than 10,000 so the failure lands while
# there is still room to fix it.
ss_cap_home="$(mktemp -d)"; ss_cap_cwd="$(mktemp -d)"
mkdir -p "$ss_cap_home/.claude/skills" "$ss_cap_home/.claude/polaris-memory" "$ss_cap_cwd/.polaris/work"
touch "$ss_cap_home/.claude/skills/.polaris-mindrally-synced" "$ss_cap_home/.claude/skills/.polaris-companions-installed"
echo '{}' > "$ss_cap_cwd/.polaris/config.json"
: > "$ss_cap_home/.claude/polaris-memory/INDEX.md"
i=0; while [ "$i" -lt 200 ]; do
  printf -- '- [entry-%03d](entries/entry-%03d.md) — a hook sentence long enough to be realistic about what one index row costs (reference, some-project)\n' "$i" "$i" \
    >> "$ss_cap_home/.claude/polaris-memory/INDEX.md"
  i=$((i + 1))
done
printf '# Work streams\n' > "$ss_cap_cwd/.polaris/work/streams.md"
i=0; while [ "$i" -lt 40 ]; do
  printf '\n## stream-%02d — a realistic stream title of the length these actually reach\n\n- status: active\n- touched: 2026-09-%02d\n' \
    "$i" $(( (i % 28) + 1 )) >> "$ss_cap_cwd/.polaris/work/streams.md"
  i=$((i + 1))
done
ss_cap_out="$( cd "$ss_cap_cwd" && echo '{}' | HOME="$ss_cap_home" CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "$SS" 2>/dev/null \
  | jq -r '.additionalContext // .hookSpecificOutput.additionalContext // ""' )"
ss_cap_len="$(printf '%s' "$ss_cap_out" | wc -c | tr -d ' ')"
[ "$ss_cap_len" -gt 0 ] && [ "$ss_cap_len" -le 9000 ] \
  && echo "ok: the session-start payload fits the hook cap (${ss_cap_len} chars)" \
  || { echo "FAIL: session-start emitted ${ss_cap_len} chars; over ~10000 the model gets a file path, not the standard"; fail=1; }
printf '%s' "$ss_cap_out" | grep -q 'context truncated at' \
  && { echo "FAIL: session-start hit its own truncation backstop, so content was cut"; fail=1; } \
  || echo "ok: the payload fits without hitting the truncation backstop"
# Truncation keeps the start of the payload, so the two rules the standard cannot do without have to
# be inside the 2KB preview that survives even when something else goes wrong.
printf '%s' "$ss_cap_out" | head -c 2000 | grep -q 'No inline comments' \
  && echo "ok: the comment law is inside the surviving 2KB preview" \
  || { echo "FAIL: the comment law is past the 2KB preview and would not survive truncation"; fail=1; }
rm -rf "$ss_cap_home" "$ss_cap_cwd"

# The rules that stopped being injected must still be named, or they are unreachable.
for r in craft writing model-routing clean-code core-protocols; do
  grep -q "${r}.md" "$SS" \
    || { echo "FAIL: session-start does not name rules/${r}.md"; fail=1; }
done
echo "ok: session-start names the rules it stopped injecting wholesale"
grep -qE 'cat "\$\{PLUGIN_ROOT\}/rules/(craft|writing|model-routing)\.md"' "$SS" \
  && { echo "FAIL: session-start still injects a rule body it cannot afford"; fail=1; } \
  || echo "ok: only core.md is resident"
[ -f "${DIR}/../rules/core-protocols.md" ] \
  && echo "ok: the protocols split out of core.md exist" \
  || { echo "FAIL: rules/core-protocols.md is missing"; fail=1; }
core_len="$(wc -c < "${DIR}/../rules/core.md" | tr -d ' ')"
[ "$core_len" -le 7000 ] \
  && echo "ok: rules/core.md is inside its 7000-byte budget (${core_len})" \
  || { echo "FAIL: rules/core.md is ${core_len} bytes; it is the only resident rules file and has a budget"; fail=1; }

# hardening: session-start surfaces a visible notice when the companion skill bulk is not synced.
# Plugin marker present (skip real `claude plugin install`); git stubbed to fail (skip network clone).
ss_home2="$(mktemp -d)"; ss_cwd2="$(mktemp -d)"; ss_bin2="$(mktemp -d)"
mkdir -p "$ss_home2/.claude/skills"; touch "$ss_home2/.claude/skills/.polaris-companions-installed"
printf '#!/bin/sh\nexit 1\n' > "$ss_bin2/git"; chmod +x "$ss_bin2/git"
ss_out2="$( cd "$ss_cwd2" && echo '{}' | HOME="$ss_home2" PATH="$ss_bin2:$PATH" bash "$SS" 2>/dev/null )"
echo "$ss_out2" | grep -q "companion skills are not installed" && echo "ok: session-start warns when skill bulk missing" || { echo "FAIL: no companion-missing notice"; fail=1; }
rm -rf "$ss_home2" "$ss_cwd2" "$ss_bin2"

# AC11: three conditional rules are named, not injected. The grep is for the read, not the path: the
# load-on-demand index names all three files on purpose, and a test that forbids the name would
# force the payload to hide where the rule lives.
grep -qE 'cat "\$\{PLUGIN_ROOT\}/rules/(routing|memory|doc-organization)\.md"' "$SS" \
  && { echo "FAIL: session-start still injects a conditional rule body"; fail=1; } \
  || echo "ok: session-start injects no conditional rule body"
for r in routing memory doc-organization; do
  grep -q "rules/${r}.md" "$SS" \
    || { echo "FAIL: session-start does not name rules/${r}.md"; fail=1; }
done
echo "ok: session-start names every rule it stopped injecting"
grep -rqF 'rules/memory.md' "${DIR}/../commands" && grep -rqF 'rules/routing.md' "${DIR}/../commands" \
  && grep -rqF 'rules/doc-organization.md' "${DIR}/../commands" \
  && echo "ok: every moved rule is loaded by a command that needs it" \
  || { echo "FAIL: a moved rule is reachable from nowhere"; fail=1; }

# AC12 and AC13: the tracker's active and blocked streams are worth the payload, its Done archive is
# history that only grows. The injection screen still reads the whole file, archive included.
ss_home3="$(mktemp -d)"; ss_cwd3="$(mktemp -d)"
mkdir -p "$ss_home3/.claude/skills" "$ss_cwd3/.polaris/work"
touch "$ss_home3/.claude/skills/.polaris-mindrally-synced" "$ss_home3/.claude/skills/.polaris-companions-installed"
printf '# Work streams\n\n## live-one\n\n- status: active\n\n## held-one\n\n- status: blocked\n\n## Done\n\n- archived-one, shipped last week\n' \
  > "$ss_cwd3/.polaris/work/streams.md"
ss_out3="$( cd "$ss_cwd3" && echo '{}' | HOME="$ss_home3" CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "$SS" 2>/dev/null )"
grep -q 'live-one' <<<"$ss_out3" && grep -q 'held-one' <<<"$ss_out3" \
  && echo "ok: session-start injects the active and blocked streams" \
  || { echo "FAIL: session-start dropped an open stream"; fail=1; }
! grep -q 'archived-one' <<<"$ss_out3" \
  && echo "ok: session-start withholds the Done archive" \
  || { echo "FAIL: session-start injected the Done archive"; fail=1; }
cat "${DIR}/fixtures/injection-bad.txt" >> "$ss_cwd3/.polaris/work/streams.md"
ss_out3="$( cd "$ss_cwd3" && echo '{}' | HOME="$ss_home3" CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "$SS" 2>/dev/null )"
grep -q 'withheld' <<<"$ss_out3" && ! grep -q 'live-one' <<<"$ss_out3" \
  && echo "ok: a tracker with injection markers is withheld whole" \
  || { echo "FAIL: an injection-marked tracker was injected"; fail=1; }
rm -rf "$ss_home3" "$ss_cwd3"

# regression: ensure-companions installs once then skips (no per-start plugin install); RCA 2026-07-16
EC="${DIR}/../scripts/ensure-companions.sh"
ec_home="$(mktemp -d)"; ec_bin="$(mktemp -d)"
printf '#!/bin/sh\necho called >> "%s/calls"\n' "$ec_home" > "$ec_bin/claude"; chmod +x "$ec_bin/claude"
mkdir -p "$ec_home/.claude/skills"; touch "$ec_home/.claude/skills/.polaris-mindrally-synced"
HOME="$ec_home" PATH="$ec_bin:$PATH" bash "$EC" >/dev/null 2>&1
c1="$([ -f "$ec_home/calls" ] && echo yes || echo no)"
: > "$ec_home/calls"
HOME="$ec_home" PATH="$ec_bin:$PATH" bash "$EC" >/dev/null 2>&1
c2="$([ -s "$ec_home/calls" ] && echo yes || echo no)"
[ "$c1" = yes ] && [ "$c2" = no ] && echo "ok: ensure-companions installs once then skips" || { echo "FAIL: ensure-companions guard (run1=$c1 run2=$c2)"; fail=1; }
: > "$ec_home/calls"
# stub git to fail fast so --force exercises the plugin re-install without a real network clone
printf '#!/bin/sh\nexit 1\n' > "$ec_bin/git"; chmod +x "$ec_bin/git"
HOME="$ec_home" PATH="$ec_bin:$PATH" bash "$EC" --force >/dev/null 2>&1
c3="$([ -s "$ec_home/calls" ] && echo yes || echo no)"
[ "$c3" = yes ] && echo "ok: ensure-companions --force re-runs after marker" || { echo "FAIL: --force did not re-sync (c3=$c3)"; fail=1; }
rm -rf "$ec_home" "$ec_bin"

# The tracker is the one injected file a project writes to every session, so it is the one that
# grows without a ceiling. The cap is what stops the /clear lever paying for it on every clear.
TS="${DIR}/../scripts/tracker-slice.sh"
ts_file="$(mktemp)"
{ printf '# Work streams\n\n'
  for n in 1 2 3 4 5; do
    printf '## stream-%s\n\n- status: active\n- touched: 2026-0%s-01\n' "$n" "$n"
    head -c 3000 /dev/zero | tr '\0' 'x'; printf '\n\n'
  done
  printf '## Done\n\n- archived-one, shipped last week\n'; } > "$ts_file"
ts_out="$(bash "$TS" "$ts_file" 10240)"
[ "$(printf '%s' "$ts_out" | wc -c)" -le 11000 ] \
  && echo "ok: the tracker slice honors its byte ceiling" \
  || { echo "FAIL: the tracker slice blew its ceiling at $(printf '%s' "$ts_out" | wc -c) bytes"; fail=1; }
[ "$(printf '%s' "$ts_out" | grep -c '^## stream-')" -lt 5 ] \
  && echo "ok: the tracker slice drops what does not fit" \
  || { echo "FAIL: the tracker slice kept every stream"; fail=1; }
printf '%s' "$ts_out" | grep -q 'not shown' \
  && echo "ok: the tracker slice names what it dropped" \
  || { echo "FAIL: the tracker slice dropped streams in silence"; fail=1; }
[ "$(printf '%s' "$ts_out" | grep -m1 '^## stream-')" = "## stream-5" ] \
  && echo "ok: the tracker slice keeps the newest stream first" \
  || { echo "FAIL: the tracker slice is not ordered newest first"; fail=1; }
printf '%s' "$ts_out" | grep -q 'archived-one' \
  && { echo "FAIL: the tracker slice injected the Done archive"; fail=1; } \
  || echo "ok: the tracker slice withholds the Done archive"
# CRLF is the quiet way the Done trim stops working: `## Done\r` never matches `## Done$`.
ts_crlf="$(mktemp)"; sed 's/$/\r/' "$ts_file" > "$ts_crlf"
bash "$TS" "$ts_crlf" 10240 | grep -q 'archived-one' \
  && { echo "FAIL: a CRLF tracker leaks its Done archive"; fail=1; } \
  || echo "ok: the Done archive is withheld from a CRLF tracker"
# An unreadable tracker must cost the tracker, never the whole session payload.
ts_unread="$(mktemp)"; cp "$ts_file" "$ts_unread"; chmod 000 "$ts_unread"
bash "$TS" "$ts_unread" 10240 >/dev/null 2>&1 \
  && echo "ok: an unreadable tracker exits clean rather than aborting" \
  || { echo "FAIL: an unreadable tracker returned non-zero"; fail=1; }
chmod 644 "$ts_unread"; rm -f "$ts_file" "$ts_crlf" "$ts_unread"

# session-start names unmerged notes, or they rot unseen.
tn_home="$(mktemp -d)"; tn_proj="$(mktemp -d)"
mkdir -p "$tn_home/.claude/skills" "$tn_proj/.polaris/work/pending"
touch "$tn_home/.claude/skills/.polaris-mindrally-synced" "$tn_home/.claude/skills/.polaris-companions-installed"
printf '## some-stream\n\n- touched: 2026-09-07\n' > "$tn_proj/.polaris/work/pending/other.md"
tn_out="$( cd "$tn_proj" && HOME="$tn_home" CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/session-start" 2>/dev/null \
  | jq -r '.additionalContext // .hookSpecificOutput.additionalContext // ""' )"
grep -q 'Unmerged tracker notes: 1' <<<"$tn_out" \
  && echo "ok: session-start names unmerged notes left by another session" \
  || { echo "FAIL: unmerged notes are invisible at session start"; fail=1; }
# It names the count and the path only. Injecting the bodies would be untrusted content and unbudgeted.
grep -q 'some-stream' <<<"$tn_out" \
  && { echo "FAIL: session-start injected pending note bodies"; fail=1; } \
  || echo "ok: session-start names the count, not the note contents"
rm -rf "$tn_home" "$tn_proj"

exit $fail
