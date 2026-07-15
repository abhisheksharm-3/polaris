#!/usr/bin/env bash
# Deterministic daily-journal facts extractor. Date in, factual markdown out.
set -uo pipefail
command -v jq >/dev/null 2>&1 || { echo "journal-facts: jq is required" >&2; exit 2; }

date="${1:?usage: journal-facts.sh <YYYY-MM-DD> [source]}"
source_label="${2:-hook}"
PROJECTS="${POLARIS_JOURNAL_PROJECTS_DIR:-$HOME/.claude/projects}"
[ -d "$PROJECTS" ] || exit 0

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Candidate transcripts: modified on/after the target day (cheap pre-filter),
# then matched exactly by message timestamp. Emit one TSV row per day-D message.
find "$PROJECTS" -type f -name '*.jsonl' -newermt "$date 00:00" -print0 2>/dev/null \
  | xargs -0 -r jq -rc --arg d "$date" '
      select((.timestamp // "") | startswith($d)) |
      select(.isSidechain != true) |
      select(.cwd != null and .cwd != "") |
      [ .cwd,
        (.sessionId // "?"),
        (.message.role // .type // "?"),
        ( (.message.content // "")
          | if type=="array" then (map(select(.type=="text") | .text) | join(" "))
            elif type=="string" then .
            else "" end ) ] | @tsv
    ' 2>/dev/null > "$tmp/rows.tsv"

[ -s "$tmp/rows.tsv" ] || exit 0   # no activity that day

cut -f1 "$tmp/rows.tsv" | sort -u > "$tmp/cwds"
projects_list="$(while read -r c; do basename "$c"; done < "$tmp/cwds" | sort -u | paste -sd, - | sed 's/,/, /g')"

printf -- '---\n'
printf 'date: %s\n' "$date"
printf 'projects: [%s]\n' "$projects_list"
printf 'status: facts\n'
printf 'generated: %s\n' "$source_label"
printf -- '---\n\n'
printf '# %s\n\n' "$date"

while read -r cwd; do
  name="$(basename "$cwd")"
  printf '## %s\n' "$name"
  sessions="$(awk -F'\t' -v c="$cwd" '$1==c{print $2}' "$tmp/rows.tsv" | sort -u | grep -c .)"
  printf -- '- Sessions: %s\n' "$sessions"
  asks="$(awk -F'\t' -v c="$cwd" '$1==c && $3=="user"{print $4}' "$tmp/rows.tsv" \
    | sed 's/\\n.*//' \
    | grep -vE '^(\[Image|<task-notification|\[SYSTEM NOTIFICATION|\[Request interrupted|<fork-boilerplate|Base directory for this skill:|Caveat:|You are a )' \
    | cut -c1-120 | awk 'NF' | awk '!seen[$0]++' | paste -sd';' - | sed 's/;/; /g')"
  [ -n "$asks" ] && printf -- '- Asked: %s\n' "$asks"
  if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    commits="$(git -C "$cwd" log --since="$date 00:00" --until="$date 23:59:59" --pretty='%h %s' 2>/dev/null | paste -sd';' - | sed 's/;/; /g')"
    [ -n "$commits" ] && printf -- '- Commits: %s\n' "$commits"
    files="$(git -C "$cwd" log --since="$date 00:00" --until="$date 23:59:59" --name-only --pretty=format: 2>/dev/null | awk 'NF' | sort -u | paste -sd, - | sed 's/,/, /g')"
    [ -n "$files" ] && printf -- '- Files: %s\n' "$files"
  fi
  printf '\n'
done < "$tmp/cwds"
