#!/usr/bin/env bash
# Runs every suite in tests/suites, or with `--changed [base]` only the suites whose `# covers:` globs
# match a file changed since base (default origin/main, else HEAD) or untracked. A change to the
# runner, tests/lib.sh, or a fixture runs everything. Exits non-zero if any suite fails.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"

all=1; changed=""
if [ "${1:-}" = "--changed" ]; then
  all=0
  base="${2:-}"
  if [ -z "$base" ]; then
    git -C "$ROOT" rev-parse -q --verify origin/main >/dev/null && base=origin/main || base=HEAD
  fi
  # A base git cannot resolve must fail the run. Running zero suites and exiting 0 would read as a
  # green suite, which is the swallowed check the ci pattern class exists to refuse.
  git -C "$ROOT" rev-parse -q --verify "${base}^{commit}" >/dev/null \
    || { echo "FAIL: --changed base '${base}' does not resolve; fetch it or name another"; exit 2; }
  changed="$( { git -C "$ROOT" diff --name-only "$base" && git -C "$ROOT" ls-files --others --exclude-standard; } | sort -u)"
  grep -qE '^tests/(lib\.sh|run-tests\.sh|fixtures/)' <<<"$changed" && all=1
fi

# True when a changed file matches one of the suite's covers globs, or the suite file itself.
selected() {
  local globs f g
  globs="$(sed -n 's/^# covers: //p' "$1") tests/suites/$(basename "$1")"
  set -f
  while IFS= read -r f; do
    for g in $globs; do
      case "$f" in $g) set +f; return 0 ;; esac
    done
  done <<<"$changed"
  set +f
  return 1
}

fail=0; times=""; ran=0
for s in "${DIR}"/suites/*.sh; do
  [ "$all" = 1 ] || selected "$s" || continue
  name="$(basename "$s" .sh)"
  ran=$((ran + 1)); start=$SECONDS
  bash "$s" || fail=1
  took=$((SECONDS - start))
  echo "suite ${name}: ${took}s"
  times="${times}${took} ${name}"$'\n'
done

echo "suites run: ${ran}"
[ -n "$times" ] && echo "slowest: $(printf '%s' "$times" | sort -rn | head -3 | awk '{printf "%s%s (%ss)", (NR>1?", ":""), $2, $1}')"
exit $fail
