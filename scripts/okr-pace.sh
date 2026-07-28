#!/usr/bin/env bash
# Per-KR OKR pace for the /sweep OKR lens. Deterministic: the command must not do this date/ratio
# math itself (core Rule 5). Emits a JSON array on stdout, one object per KR.
set -euo pipefail

now=""; progress=""
while [ $# -gt 0 ]; do
  case "$1" in
    --now) now="${2:-}"; shift 2 ;;
    --progress) progress="${2:-}"; shift 2 ;;
    *) echo "okr-pace: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$now" ] || { echo "okr-pace: --now <iso-or-date> required" >&2; exit 2; }
[ -n "$progress" ] && [ -f "$progress" ] || { echo "okr-pace: --progress <existing file> required" >&2; exit 2; }

jq -c --arg now "$now" '
  # A date-only string (length 10) gets midnight UTC appended before parsing.
  def ep: (if (. | length) == 10 then . + "T00:00:00Z" else . end) | fromdateiso8601;
  ($now | ep) as $n
  | (.periodStart | ep) as $p0
  | .krs | map(
      if (.kind // "num") == "flag"
      then { id: .id, status: "flag", done: (.current >= .target) }
      else
        (.deadline | ep) as $d
        | (if $d <= $p0 then 1 else (($n - $p0) / ($d - $p0)) end) as $ef0
        | (if $ef0 < 0 then 0 elif $ef0 > 1 then 1 else $ef0 end) as $ef
        | ($ef * .target) as $expected
        | ($expected - .current) as $gap
        | if $gap > 0.5 then { id: .id, status: "behind", needToCatch: ($gap | ceil) }
          elif (.current - $expected) > 0.5 then { id: .id, status: "ahead" }
          else { id: .id, status: "on-track" }
          end
      end
    )' "$progress"
