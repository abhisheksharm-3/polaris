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
  # Blank out fenced code blocks (line numbers preserved) so code/config examples
  # aren't linted for English banned words — a ```json``` sample is not prose.
  local body
  body="$(awk '/^```/{f=!f; print ""; next} f{print ""; next} {print}' "$file")"
  while IFS= read -r word; do
    grep -niwE "$word" <<<"$body" | while IFS=: read -r ln _; do
      echo "$file:$ln: banned-word: '$word'"
    done
  done < <(jq -r '.prose.banned_words[]' "$PATTERNS")
  jq -c '.prose.banned_regex[]' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nEi "$pat" <<<"$body" | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

scan_code() {
  local file="$1" lang=""
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx) lang=ts;;
    *.py)                   lang=py;;
    *.go)                   lang=go;;
    *.rs)                   lang=rust;;
  esac
  [ -n "$lang" ] || return 0
  jq -c --arg l "$lang" '.code[$l][]? // empty' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nE "$pat" "$file" 2>/dev/null | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

scan_injection() {
  local file="$1"
  # ponytail: regex denylist over known injection phrasings; a model classifier is
  # the upgrade path if paraphrase evasion becomes a real problem. The hook that calls
  # this hands flagged content to the model, which is the actual classifier in the loop.
  while IFS= read -r phrase; do
    grep -niE "$phrase" "$file" 2>/dev/null | while IFS=: read -r ln _; do
      echo "$file:$ln: injection: '$phrase'"
    done
  done < <(jq -r '.injection.phrases[]' "$PATTERNS")
}

for file in "$@"; do
  [ -f "$file" ] || continue
  case "$file" in rules/*|*/rules/*|output-styles/*|*/output-styles/*|*patterns.json) continue;; esac
  out=""
  case "$scope" in
    prose)     out="$(scan_prose "$file")";;
    code)      out="$(scan_code "$file")";;
    injection) out="$(scan_injection "$file")";;
    both)      out="$(scan_prose "$file"; scan_code "$file")";;
  esac
  if [ -n "$out" ]; then echo "$out"; found=1; fi
done

exit $found
