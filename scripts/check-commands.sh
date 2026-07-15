#!/usr/bin/env bash
# Assert every agent named (backticked) in commands/flow.md exists as an agent file.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
FLOW="${ROOT}/commands/flow.md"
fail=0

[ -f "$FLOW" ] || { echo "check-commands: flow.md not found" >&2; exit 2; }

for token in $(grep -oE '`[a-z0-9][a-z0-9-]*`' "$FLOW" | tr -d '`' | sort -u); do
  if [ -f "${ROOT}/agents/${token}.md" ]; then
    echo "ok ${token}"
  else
    echo "FAIL: flow.md references '${token}' but agents/${token}.md does not exist"
    fail=1
  fi
done

exit $fail
