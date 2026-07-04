#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "check-patterns: jq is required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PATTERNS="${ROOT}/rules/patterns.json"
[ -f "$PATTERNS" ] || { echo "check-patterns: patterns.json not found at $PATTERNS" >&2; exit 2; }

scope="${1:-both}"; shift || true
found=0

scan_prose() {
  local file="$1"
  case "$file" in */rules/*|*patterns.json) return 0;; esac
  while IFS= read -r word; do
    grep -niwE "$word" "$file" 2>/dev/null | while IFS=: read -r ln _; do
      echo "$file:$ln: banned-word: '$word'"
    done
  done < <(jq -r '.prose.banned_words[]' "$PATTERNS")
  jq -c '.prose.banned_regex[]' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nEi "$pat" "$file" 2>/dev/null | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

scan_code() {
  local file="$1"
  jq -c '.code.ts[]' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nE "$pat" "$file" 2>/dev/null | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

for file in "$@"; do
  [ -f "$file" ] || continue
  out=""
  case "$scope" in
    prose) out="$(scan_prose "$file")";;
    code)  out="$(scan_code "$file")";;
    both)  out="$(scan_prose "$file"; scan_code "$file")";;
  esac
  if [ -n "$out" ]; then echo "$out"; found=1; fi
done

exit $found
