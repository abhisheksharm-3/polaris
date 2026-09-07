#!/usr/bin/env bash
# Resolve the manager 1:1 from calendar structure, and join that interval to its Fathom recording.
# Deterministic: the command must not do this arithmetic or these field tests itself (core Rule 5).
# Two subcommands. `series` reads a list_events array and picks the recurring two-attendee series,
# emitting each instance with its forward ingest bracket. `claim` reads the bracketed list_meetings
# array for one instance and returns resolved, ambiguous, or none.
set -uo pipefail

LAG_HOURS_DEFAULT=3

# Google Calendar returns local offsets ("+05:30") and all-day dates; jq's fromdateiso8601 accepts
# only "...Z". Every timestamp is normalised through this before any arithmetic, and every timestamp
# this script emits is in Z form, because Fathom's created_after filter accepts nothing else.
ISO2EPOCH='def iso2epoch:
  (. | capture("^(?<b>[0-9]{4}-[0-9]{2}-[0-9]{2})(T(?<t>[0-9]{2}:[0-9]{2}:[0-9]{2}))?(?<z>Z|[+-][0-9]{2}:[0-9]{2})?")) as $m
  | (($m.b + "T" + ($m.t // "00:00:00") + "Z") | fromdateiso8601) as $e
  | if ($m.z // "Z") == "Z" then $e
    else ($m.z | capture("^(?<sg>[+-])(?<h>[0-9]{2}):(?<mi>[0-9]{2})")) as $o
      | $e - ((($o.h | tonumber) * 3600 + ($o.mi | tonumber) * 60) * (if $o.sg == "-" then -1 else 1 end))
    end;
def isoz: iso2epoch | todateiso8601;'

cmd_series() {
  jq -c --arg self "$self" --arg pinned "$pinned" --argjson lag "$lag" "$ISO2EPOCH"'
    def isself($a): (($a.self // false) == true) or (($a.email // "" | ascii_downcase) == ($self | ascii_downcase));
    def cand: select((.recurringEventId // "") != "")
            | select((.attendees // []) | length == 2)
            | select([ .attendees[] | select(isself(.)) ] | length == 1);
    . as $all
    | [ .[] | cand ] as $c
    | ($c | group_by(.recurringEventId)) as $groups
    | (if ($pinned | length) > 0
       then [ $groups[] | select(.[0].recurringEventId == $pinned) ]
       else $groups end) as $g0
    | (if ($g0 | length) > 1
       then ([ $g0[] | select(any(.[]; (.summary // "") | ascii_downcase | test("1:1|one[- ]on[- ]one"))) ]
             | if length == 1 then . else $g0 end)
       else $g0 end) as $g
    | if ($g | length) == 0 then { status: "none" }
      elif ($g | length) > 1 then
        { status: "ambiguous",
          candidates: [ $g[] | { recurringEventId: .[0].recurringEventId,
                                 title: (.[0].summary // ""), instances: length } ] }
      else
        ($g[0]) as $s
        | ($s[0].attendees | map(select(isself(.) | not)) | .[0]) as $mgr
        | { status: "ok",
            recurringEventId: $s[0].recurringEventId,
            manager: { email: ($mgr.email // ""), name: ($mgr.displayName // $mgr.email // "") },
            lagHours: $lag,
            instances: [ $s[] | (.start.dateTime // .start.date) as $st | (.end.dateTime // .end.date) as $en
              | { date: ($st | iso2epoch | strftime("%Y-%m-%d")),
                  start: ($st | isoz), end: ($en | isoz), title: (.summary // ""),
                  createdAfter: ($st | isoz),
                  createdBefore: (($en | iso2epoch) + ($lag * 3600) | todateiso8601) } ],
            otherTitles: ([ $all[] | select((.recurringEventId // "") == "" or (.attendees // [] | length) != 2)
                          | (.summary // "") | select(length > 0) ] | unique) }
      end'
}

cmd_claim() {
  local titles="[]"
  [ -n "$titles_file" ] && [ -f "$titles_file" ] && titles="$(jq -Rcn '[inputs | ascii_downcase]' "$titles_file")"
  jq -c --argjson titles "$titles" --arg att "$attendees" \
        --arg ca "$created_after" --arg cb "$created_before" "$ISO2EPOCH"'
    def inv: [ .calendar_invitees[]? | (.email // "") | ascii_downcase ] | sort;
    ($att | ascii_downcase | split(",") | map(select(length > 0)) | sort) as $want
    | [ .[] | . + { _inv: inv } ] as $all
    | [ $all[] | select((._inv | length) > 0 and ._inv == $want) ] as $tierA
    | [ $all[] | select((._inv | length) == 0)
              | select((.title // "" | ascii_downcase) as $t | ($titles | index($t)) == null) ] as $tierB
    | (if ($tierA | length) > 0 then $tierA else $tierB end) as $un
    | ($un | sort_by(.recording_id)) as $s
    | def shape($m; $labeled):
        { status: "resolved", recordingId: $m.recording_id, url: ($m.url // ""),
          labeled: $labeled, tier: (if $labeled then "A" else "B" end),
          lagMinutes: (if ($m.created // null) == null or ($ca | length) == 0 then null
                       else ((($m.created | iso2epoch) - ($ca | iso2epoch)) / 60 | floor) end) };
      if ($s | length) == 1 then shape($s[0]; ($tierA | length) > 0)
      elif ($s | length) > 1 then
        { status: "ambiguous", default: $s[0].recording_id,
          candidates: [ $s[] | { recordingId: .recording_id, title: (.title // ""),
                                 durationMinutes: (.duration_minutes // null), url: (.url // "") } ] }
      else { status: "none", bracket: { createdAfter: $ca, createdBefore: $cb } } end'
}

cmd_widen() { echo $(( lag * 4 )); }

sub="${1:-}"; shift || true
self=""; pinned=""; attendees=""; titles_file=""; created_after=""; created_before=""
lag="$LAG_HOURS_DEFAULT"
while [ $# -gt 0 ]; do
  case "$1" in
    --self) self="${2:-}"; shift 2 ;;
    --pinned) pinned="${2:-}"; shift 2 ;;
    --attendees) attendees="${2:-}"; shift 2 ;;
    --titles) titles_file="${2:-}"; shift 2 ;;
    --created-after) created_after="${2:-}"; shift 2 ;;
    --created-before) created_before="${2:-}"; shift 2 ;;
    --lag-hours) lag="${2:-}"; shift 2 ;;
    *) echo "oneonone-join: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$sub" in
  series) cmd_series ;;
  claim)  cmd_claim ;;
  widen)  cmd_widen ;;
  *) echo "oneonone-join: usage: oneonone-join.sh series|claim|widen [options]" >&2; exit 2 ;;
esac
