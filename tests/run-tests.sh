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
# code: bad flagged, clean passes
expect_exit 1 "$CHECK" code "${DIR}/fixtures/bad-ts.ts"
expect_exit 0 "$CHECK" code "${DIR}/fixtures/clean.ts"

# guard-commit-pr: bad commit message denied, good allowed
GUARD="${DIR}/../hooks/guard-commit-pr"
bad_msg="$(cat "${DIR}/fixtures/commit-bad.txt")"
good_msg="$(cat "${DIR}/fixtures/commit-good.txt")"
bad_payload="$(jq -n --arg c "git commit -m \"${bad_msg}\"" '{tool_input:{command:$c}}')"
good_payload="$(jq -n --arg c "git commit -m \"${good_msg}\"" '{tool_input:{command:$c}}')"
if echo "$bad_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"'; then echo "ok: bad commit denied"; else echo "FAIL: bad commit not denied"; fail=1; fi
if echo "$good_payload" | "$GUARD" | grep -q '"permissionDecision":"deny"'; then echo "FAIL: good commit denied"; fail=1; else echo "ok: good commit allowed"; fi

exit $fail
