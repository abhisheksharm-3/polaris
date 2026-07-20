#!/usr/bin/env bash
# Compute the pull window for /sweep. Deterministic: the command must not do this date math itself
# (core-standard Rule 5). Times are UTC (ISO-8601 Z). Emits one JSON object on stdout.
set -euo pipefail

now=""; state=""; max=168
while [ $# -gt 0 ]; do
  case "$1" in
    --now) now="${2:-}"; shift 2 ;;
    --state) state="${2:-}"; shift 2 ;;
    --max-lookback-hours) max="${2:-}"; shift 2 ;;
    *) echo "sweep-window: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$now" ] || { echo "sweep-window: --now <iso-Z> required" >&2; exit 2; }

last=""
if [ -n "$state" ] && [ -f "$state" ]; then
  last="$(jq -r '.lastRunAt // empty' "$state" 2>/dev/null || true)"
fi

jq -cn --arg now "$now" --arg last "$last" --argjson max "$max" '
  def firstrun($n): { start: (($n - 86400) | todateiso8601), firstRun: true, capped: false, trueGapHours: 24 };
  ($now | fromdateiso8601) as $n
  | ($max * 3600) as $cap
  | ($last | try fromdateiso8601 catch null) as $l
  # No cursor, an unparseable cursor, or a cursor at/after now (clock skew, corrupt state):
  # fall back to a first run rather than crashing or pulling a backwards window.
  | if ($last | length) == 0 or $l == null then firstrun($n)
    else
      ($n - $l) as $gap
      | (($gap / 3600) | floor) as $gaph
      | if $gap <= 0 then firstrun($n)
        elif $gap > $cap then
          { start: (($n - $cap) | todateiso8601), firstRun: false, capped: true,  trueGapHours: $gaph }
        else
          { start: $last,                         firstRun: false, capped: false, trueGapHours: $gaph }
        end
    end'
