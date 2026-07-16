#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="${DIR}/../scripts/check-patterns.sh"
fail=0

expect_exit() {
  local want="$1"; shift
  "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" != "$want" ]; then echo "FAIL: want exit $want got $got: $*"; fail=1;
  else echo "ok: $*"; fi
}

# prose: bad flagged, clean passes
expect_exit 1 "$CHECK" prose "${DIR}/fixtures/bad-prose.md"
expect_exit 0 "$CHECK" prose "${DIR}/fixtures/clean-prose.md"
# code: bad flagged, clean passes (per language)
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad-ts.ts"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.ts"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.py"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.py"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.go"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.go"
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad.rs"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.rs"

# injection: bad flagged, clean passes, paraphrase (no literal denylist match) still flagged
expect_exit 1 "$CHECK" injection "${DIR}/fixtures/injection-bad.txt"
expect_exit 0 "$CHECK" injection "${DIR}/fixtures/injection-clean.txt"
expect_exit 1 "$CHECK" injection "${DIR}/fixtures/injection-paraphrase.txt"

# guard-commit-pr: bad commit message denied, good allowed
GUARD="${DIR}/../hooks/guard-commit-pr"
bad_msg="$(cat "${DIR}/fixtures/commit-bad.txt")"
good_msg="$(cat "${DIR}/fixtures/commit-good.txt")"
bad_payload="$(jq -n --arg c "git commit -m \"${bad_msg}\"" '{tool_input:{command:$c}}')"
good_payload="$(jq -n --arg c "git commit -m \"${good_msg}\"" '{tool_input:{command:$c}}')"
if echo "$bad_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"'; then echo "ok: bad commit denied"; else echo "FAIL: bad commit not denied"; fail=1; fi
if echo "$good_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"'; then echo "FAIL: good commit denied"; fail=1; else echo "ok: good commit allowed"; fi

# guard-input: injection in a tool result flagged, clean stays silent
GINPUT="${DIR}/../hooks/guard-input"
inj_bad="$(jq -n --rawfile t "${DIR}/fixtures/injection-bad.txt" '{tool_response:$t}')"
inj_clean="$(jq -n --rawfile t "${DIR}/fixtures/injection-clean.txt" '{tool_response:$t}')"
if echo "$inj_bad"   | "$GINPUT" | grep -q 'additionalContext'; then echo "ok: injection flagged"; else echo "FAIL: injection not flagged"; fail=1; fi
if echo "$inj_clean" | "$GINPUT" | grep -q 'additionalContext'; then echo "FAIL: clean flagged"; fail=1; else echo "ok: clean tool result silent"; fi

# agent frontmatter valid
expect_exit 0 bash "${DIR}/../scripts/check-agents.sh"

# flow.md references only real agents
expect_exit 0 bash "${DIR}/../scripts/check-commands.sh"

# enhance-prompt: injects when enabled, silent when disabled
ENH="${DIR}/../hooks/enhance-prompt"
tmp_on="$(mktemp -d)"; mkdir -p "${tmp_on}/.polaris"; echo '{"promptEnhance":true}' > "${tmp_on}/.polaris/config.json"
tmp_off="$(mktemp -d)"; mkdir -p "${tmp_off}/.polaris"; echo '{"promptEnhance":false}' > "${tmp_off}/.polaris/config.json"
payload='{"prompt":"make the thing better"}'
if echo "$payload" | CLAUDE_PROJECT_DIR="$tmp_on"  "$ENH" | grep -q 'additionalContext'; then echo "ok: enhance injects when enabled"; else echo "FAIL: enhance did not inject when enabled"; fail=1; fi
if echo "$payload" | CLAUDE_PROJECT_DIR="$tmp_off" "$ENH" | grep -q 'additionalContext'; then echo "FAIL: enhance injected when disabled"; fail=1; else echo "ok: enhance silent when disabled"; fi
rm -rf "$tmp_on" "$tmp_off"

# guard-edit: warns on slop in an edited file when enabled, silent when disabled
GEDIT="${DIR}/../hooks/guard-edit"
ge_on="$(mktemp -d)";  mkdir -p "${ge_on}/.polaris";  echo '{"guardEdit":true}'  > "${ge_on}/.polaris/config.json"
ge_off="$(mktemp -d)"; mkdir -p "${ge_off}/.polaris"; echo '{"guardEdit":false}' > "${ge_off}/.polaris/config.json"
ge_payload="$(jq -n --arg f "${DIR}/fixtures/bad-ts.ts" '{tool_input:{file_path:$f}}')"
if echo "$ge_payload" | CLAUDE_PROJECT_DIR="$ge_on"  "$GEDIT" | grep -q 'additionalContext'; then echo "ok: guard-edit warns when enabled"; else echo "FAIL: guard-edit did not warn when enabled"; fail=1; fi
if echo "$ge_payload" | CLAUDE_PROJECT_DIR="$ge_off" "$GEDIT" | grep -q 'additionalContext'; then echo "FAIL: guard-edit warned when disabled"; fail=1; else echo "ok: guard-edit silent when disabled"; fi
rm -rf "$ge_on" "$ge_off"

# journal-facts: buckets a day's activity by project, excludes other days
JF="${DIR}/../scripts/journal-facts.sh"
jf_out="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" bash "$JF" 2026-07-14)"
echo "$jf_out" | grep -q '## demo'              && echo "ok: journal project section" || { echo "FAIL: journal project section"; fail=1; }
echo "$jf_out" | grep -q 'Sessions: 2'          && echo "ok: journal session count"    || { echo "FAIL: journal session count"; fail=1; }
echo "$jf_out" | grep -q 'add the login form'   && echo "ok: journal ask captured"      || { echo "FAIL: journal ask captured"; fail=1; }
echo "$jf_out" | grep -q 'fix the checkout bug' && echo "ok: journal second ask"        || { echo "FAIL: journal second ask"; fail=1; }
if echo "$jf_out" | grep -q 'OTHER DAY'; then echo "FAIL: journal leaked another day"; fail=1; else echo "ok: journal excludes other days"; fi

# worktracker-snapshot: commits after the marker are captured, a future marker yields nothing
WTS="${DIR}/../scripts/worktracker-snapshot.sh"
wt_repo="$(mktemp -d)"
(
  cd "$wt_repo" && git init -q && git config user.email t@t && git config user.name t
  GIT_AUTHOR_DATE="2026-07-15T12:00:00Z" GIT_COMMITTER_DATE="2026-07-15T12:00:00Z" \
    sh -c 'echo hi > a.txt && git add a.txt && git commit -qm "add the widget"'
)
wt_empty="$(mktemp -d)"   # no transcripts, so git commits are the signal under test
wt_before="$(POLARIS_JOURNAL_PROJECTS_DIR="$wt_empty" bash "$WTS" "$wt_repo" "2026-07-15T00:00:00Z")"
wt_after="$(POLARIS_JOURNAL_PROJECTS_DIR="$wt_empty" bash "$WTS" "$wt_repo" "2026-07-16T00:00:00Z")"
echo "$wt_before" | grep -q 'add the widget' && echo "ok: worktracker captures commit since marker" || { echo "FAIL: worktracker missed commit"; fail=1; }
echo "$wt_before" | grep -q 'a.txt'          && echo "ok: worktracker lists touched file"          || { echo "FAIL: worktracker missed file"; fail=1; }
if [ -n "$wt_after" ]; then echo "FAIL: worktracker emitted for a future marker"; fail=1; else echo "ok: worktracker silent when nothing new"; fi
rm -rf "$wt_repo" "$wt_empty"

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
rm -rf "$ec_home" "$ec_bin"

exit $fail
