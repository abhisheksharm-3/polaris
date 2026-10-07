#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "check-patterns: jq is required" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}"
PATTERNS="${ROOT}/rules/patterns.json"
ROOT_REAL="$(cd "$ROOT" && pwd -P)"
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
    grep -niwE -e "$word" <<<"$body" | while IFS=: read -r ln _; do
      echo "$file:$ln: banned-word: '$word'"
    done
  done < <(jq -r '.prose.banned_words[]' "$PATTERNS")
  jq -c '.prose.banned_regex[]' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    grep -nEi -e "$pat" <<<"$body" | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg"; done
  done
}

scan_rules() {
  local file="$1" lang="$2"
  jq -c --arg l "$lang" '.code[$l][]? // empty' "$PATTERNS" | while read -r rule; do
    pat=$(echo "$rule" | jq -r '.pattern'); id=$(echo "$rule" | jq -r '.id'); msg=$(echo "$rule" | jq -r '.message')
    unless=$(echo "$rule" | jq -r '.unless // "^$"')
    icase=$(echo "$rule" | jq -r 'if .ignoreCase then "i" else "" end')
    tag=$(echo "$rule" | jq -r 'if .severity == "advisory" then " (advisory)" else "" end')
    grep -n${icase}E -e "$pat" "$file" 2>/dev/null | grep -v${icase}E -e "^[0-9]+:.*(${unless})" | while IFS=: read -r ln _; do echo "$file:$ln: $id: $msg$tag"; done
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
  [ -n "$lang" ] && scan_rules "$file" "$lang"
  case "$file" in
    *.tsx|*.jsx|*.vue|*.svelte|*.astro|*.html|*.css|*.scss) scan_rules "$file" ui;;
  esac
  case "$file" in
    *.test.*|*.spec.*|*_test.go|*_test.py|test_*.py|*/test_*.py|*/__tests__/*|__tests__/*|*/tests/*.py|tests/*.py) scan_rules "$file" test;;
  esac
  case "$file" in
    *.sql|*/migrations/*|migrations/*|*/migrate/*|migrate/*) scan_rules "$file" migration;;
  esac
  case "$file" in
    */.github/workflows/*|.github/workflows/*|*.gitlab-ci.yml|*/.circleci/*|.circleci/*|*/lefthook.yml|lefthook.yml|*/.husky/*|.husky/*) scan_rules "$file" ci;;
  esac
  return 0
}

scan_injection() {
  local file="$1"
  # ponytail: regex denylist over known injection phrasings; a model classifier is
  # the upgrade path if paraphrase evasion becomes a real problem. The hook that calls
  # this hands flagged content to the model, which is the actual classifier in the loop.
  while IFS= read -r phrase; do
    grep -niE -e "$phrase" "$file" 2>/dev/null | while IFS=: read -r ln _; do
      echo "$file:$ln: injection: '$phrase'"
    done
  done < <(jq -r '.injection.phrases[]' "$PATTERNS")
}

for file in "$@"; do
  [ -f "$file" ] || continue
  # Polaris's own rule files quote the banned words and patterns they define, so they are exempt. Only
  # these files, by real path: a segment match exempted every user file under a rules/ directory,
  # which turned off the comment law there once guard-edit staged files at their real path.
  real="$(cd "$(dirname "$file")" 2>/dev/null && pwd -P)/$(basename "$file")"
  case "$real" in "${ROOT_REAL}/rules/"*|"${ROOT_REAL}/output-styles/"*) continue;; esac
  out=""
  case "$scope" in
    prose)     out="$(scan_prose "$file")";;
    code)      out="$(scan_code "$file")";;
    injection) out="$(scan_injection "$file")";;
    both)      out="$(scan_prose "$file"; scan_code "$file")";;
  esac
  if [ -n "$out" ]; then
    echo "$out"
    # An advisory finding is printed for a human to judge and never fails the check: a migration that
    # drops a column is sometimes exactly right, and a hard stop there only teaches a workaround.
    grep -qv ' (advisory)$' <<<"$out" && found=1
  fi
done

exit $found
