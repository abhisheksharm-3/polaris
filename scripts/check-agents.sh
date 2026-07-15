#!/usr/bin/env bash
# Validate plugin-agent frontmatter: required fields present, model tier valid,
# no forbidden fields (hooks/mcpServers/permissionMode are ignored for plugin agents).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
fail=0

for f in "${ROOT}"/agents/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$f")"

  echo "$fm" | grep -qE '^name:' || { echo "FAIL $name: missing name"; fail=1; }
  echo "$fm" | grep -qE '^description:' || { echo "FAIL $name: missing description"; fail=1; }
  model="$(echo "$fm" | grep -m1 -E '^model:' | awk '{print $2}')"
  case "$model" in
    opus|sonnet|haiku) ;;
    *) echo "FAIL $name: model must be opus/sonnet/haiku, got '${model:-none}'"; fail=1;;
  esac
  for bad in hooks mcpServers permissionMode; do
    echo "$fm" | grep -qE "^${bad}:" && { echo "FAIL $name: forbidden field '${bad}' (ignored for plugin agents)"; fail=1; }
  done
  echo "$fm" | grep -qE '^skills:' || echo "warn $name: no skills field"
  [ "$fail" = 0 ] && echo "ok $name" || true
done

exit $fail
