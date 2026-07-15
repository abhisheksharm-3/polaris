#!/usr/bin/env bash
# Validate cross-references across the plugin:
#  1. Every agent named on a "dispatch" line in any command exists as agents/<name>.md.
#  2. Every entry in each agent's `skills:` frontmatter is a well-formed skill token.
# Tokens that resolve to a local skill or a command are skipped in (1): a command may
# legitimately backtick those on a dispatch line.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
fail=0

nonagent="$( { ls "${ROOT}/skills" 2>/dev/null; ls "${ROOT}/commands" 2>/dev/null | sed 's/\.md$//'; } | sort -u)"

# 1. dispatched agents exist
for f in "${ROOT}"/commands/*.md; do
  [ -f "$f" ] || continue
  cmd="$(basename "$f" .md)"
  for token in $(grep -iE 'dispatch' "$f" | grep -oE '`[a-z][a-z0-9-]*`' | tr -d '`' | sort -u); do
    printf '%s\n' "$nonagent" | grep -qx "$token" && continue
    if [ -f "${ROOT}/agents/${token}.md" ]; then
      echo "ok ${cmd} -> ${token}"
    else
      echo "FAIL: ${cmd} dispatches '${token}' but agents/${token}.md does not exist"
      fail=1
    fi
  done
done

# 2. agent skills frontmatter is well-formed
for f in "${ROOT}"/agents/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  line="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f&&/^skills:/{sub(/^skills:[[:space:]]*/,"");print;exit}' "$f")"
  [ -n "$line" ] || continue
  IFS=',' read -ra arr <<< "$line"
  for s in "${arr[@]}"; do
    s="$(echo "$s" | xargs)"
    [ -n "$s" ] || continue
    if ! echo "$s" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
      echo "FAIL: ${name} skills entry '${s}' is not a well-formed skill token"
      fail=1
    fi
  done
done

exit $fail
