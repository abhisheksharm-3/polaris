# Shared by every suite in tests/suites: the paths, the fail flag, and the helpers more than one area uses.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The working-life half is a second plugin in this repo since 2026-09-07, so its scripts, commands
# and rules live under plugins/polaris-work. One suite still covers both: they ship separately but
# they are developed together, and a forked suite is one that stops being run.
WORK="${DIR}/../plugins/polaris-work"
CHECK="${DIR}/../scripts/check-patterns.sh"
fail=0

expect_exit() {
  local want="$1"; shift
  "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" != "$want" ]; then echo "FAIL: want exit $want got $got: $*"; fail=1;
  else echo "ok: $*"; fi
}

# The context inject-standard hands a subagent of the given type, for the design and testing suites.
is_ctx() { printf '{"agent_type":"%s"}' "$1" | CLAUDE_PLUGIN_ROOT="${DIR}/.." bash "${DIR}/../hooks/inject-standard" \
  | jq -r '.hookSpecificOutput.additionalContext // ""'; }
