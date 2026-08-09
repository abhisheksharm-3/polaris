#!/usr/bin/env bash
# The 1:1 inbox: what the user wants to raise, captured between meetings and spent on one agenda.
# Deterministic: numbering, the five-per-agenda cap, and the consumed/open split are file arithmetic,
# not judgment (core Rule 5). One item per line, appended, never rewritten in place except through a
# temp file and one mv, so a failure mid-write cannot half-consume the inbox.
set -uo pipefail

INBOX_DIR="${HOME}/.claude/polaris-memory/oneonone"
INBOX="${INBOX_DIR}/inbox.md"
MAX_PER_AGENDA=5

open_count() { grep -c '^- \[ \] ' "$INBOX" 2>/dev/null || echo 0; }

cmd_add() {
  local text
  text="$(printf '%s' "$*" | tr '\n\r\t' '   ' | tr -s ' ' | sed 's/^ *//; s/ *$//')"
  [ -n "$text" ] || { echo "oneonone add: nothing to add; pass the item text" >&2; exit 2; }
  mkdir -p "$INBOX_DIR"
  printf -- '- [ ] %s · %s\n' "$date" "$text" >> "$INBOX"
  echo "${INBOX} · $(open_count) open"
}

cmd_list() {
  [ -f "$INBOX" ] || exit 0
  awk -F' · ' '
    /^- \[ \] / {
      n++
      split($1, d, "] ")
      text = $0
      sub(/^- \[ \] [0-9-]+ · /, "", text)
      printf "%d\t%s\t%s\n", n, d[2], text
      next
    }
    /^- \[x\] / { next }
    /^[[:space:]]*$/ { next }
    { printf "inbox: line %d does not parse\n", NR > "/dev/stderr" }
  ' "$INBOX"
}

cmd_consume() {
  [ -f "$INBOX" ] || { echo "oneonone consume: no inbox to consume" >&2; exit 2; }
  [ "$#" -le "$MAX_PER_AGENDA" ] || { echo "inbox consume: at most ${MAX_PER_AGENDA} items per agenda" >&2; exit 2; }
  [ "$#" -gt 0 ] || { echo "inbox consume: name at least one item" >&2; exit 2; }
  local total ids
  total="$(open_count)"
  for n in "$@"; do
    case "$n" in
      ''|*[!0-9]*) echo "inbox consume: not an item number: ${n}" >&2; exit 2 ;;
    esac
    [ "$n" -ge 1 ] && [ "$n" -le "$total" ] || { echo "inbox consume: no open item ${n}; ${total} open" >&2; exit 2; }
  done
  ids=" $* "
  local tmp; tmp="$(mktemp)"
  awk -v ids="$ids" -v d="$date" '
    /^- \[ \] / {
      n++
      if (index(ids, " " n " ") > 0) { sub(/^- \[ \]/, "- [x]"); print $0 " · raised " d; next }
    }
    { print }
  ' "$INBOX" > "$tmp" && mv "$tmp" "$INBOX"
  echo "$# consumed"
}

cmd_restore() {
  [ -f "$INBOX" ] || { echo "oneonone restore: no inbox to restore" >&2; exit 2; }
  local marked; marked="$(grep -c "^- \[x\] .* · raised ${date}\$" "$INBOX" 2>/dev/null || echo 0)"
  [ "$marked" -gt 0 ] || { echo "inbox restore: nothing was consumed on ${date}" >&2; exit 2; }
  local ids=""
  if [ "$#" -gt 0 ]; then
    for n in "$@"; do
      case "$n" in
        ''|*[!0-9]*) echo "inbox restore: not an item number: ${n}" >&2; exit 2 ;;
      esac
      [ "$n" -ge 1 ] && [ "$n" -le "$marked" ] || { echo "inbox restore: no item ${n} consumed on ${date}; ${marked} consumed" >&2; exit 2; }
    done
    ids=" $* "
  fi
  local tmp; tmp="$(mktemp)"
  awk -v ids="$ids" -v d="$date" '
    $0 ~ ("^- \\[x\\] .* · raised " d "$") {
      n++
      if (ids == "" || index(ids, " " n " ") > 0) {
        sub(/^- \[x\]/, "- [ ]"); sub(" · raised " d "$", ""); print; next
      }
    }
    { print }
  ' "$INBOX" > "$tmp" && mv "$tmp" "$INBOX"
  echo "restored"
}

sub="${1:-}"; shift || true
date="$(date +%F)"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --date) date="${2:-}"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

case "$sub" in
  add)     cmd_add ${args+"${args[@]}"} ;;
  list)    cmd_list ;;
  consume) cmd_consume ${args+"${args[@]}"} ;;
  restore) cmd_restore ${args+"${args[@]}"} ;;
  *) echo "oneonone-inbox: usage: oneonone-inbox.sh add|list|consume|restore [--date YYYY-MM-DD] [args]" >&2; exit 2 ;;
esac
