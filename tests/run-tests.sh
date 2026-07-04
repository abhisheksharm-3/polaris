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

exit $fail
