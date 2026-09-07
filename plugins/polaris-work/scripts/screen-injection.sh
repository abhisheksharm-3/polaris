#!/usr/bin/env bash
# Screen text for prompt-injection markers. Exit 1 when something is flagged, 0 when clean.
#
# The root plugin does this with scripts/check-patterns.sh, which polaris-work cannot reach: two
# plugins ship independently, so neither can call the other's files. Mirroring the whole of
# check-patterns.sh would drag rules/patterns.json across with it, and that file also holds the
# prose, code and routing classes this plugin has no use for. The injection list is eight phrases,
# so this carries those and nothing else.
#
# Kept in step with the root plugin by a test that compares this phrase list against
# rules/patterns.json .injection.phrases. Edit that file, then this one.
#
# Usage: screen-injection.sh <file>   (exit 1 = flagged, and the matches go to stdout)
set -uo pipefail

file="${1:-}"
[ -n "$file" ] && [ -r "$file" ] || exit 0

phrases=(
  "(ignore|disregard|forget|override|bypass) (the |all |any |your |these |those |previous |prior |earlier |above )*(instruction|guidance|rule|prompt|direction|command)"
  "(ignore|disregard|forget|override) (the )?(above|previous|prior|earlier|preceding|foregoing)"
  "you are now (a |an |the )?"
  "(reveal|print|show|repeat|output|share|expose|leak|disclose|dump) (me |us )?(your|the) (system |initial |original |developer )?(prompt|instruction|rule|guideline|configuration)"
  "(system|developer) prompt"
  "new instructions?:"
  "exfiltrat"
  "act as (a |an )?(dan|jailbreak|unrestricted|unfiltered)"
)

found=0
for phrase in "${phrases[@]}"; do
  while IFS=: read -r ln _; do
    [ -n "$ln" ] || continue
    echo "${file}:${ln}: injection: '${phrase}'"
    found=1
  done < <(grep -niE "$phrase" "$file" 2>/dev/null || true)
done

exit $found
