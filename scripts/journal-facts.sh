#!/usr/bin/env bash
# Deterministic daily-journal facts extractor. Date in, factual markdown out.
set -uo pipefail
command -v jq >/dev/null 2>&1 || { echo "journal-facts: jq is required" >&2; exit 2; }

date="${1:?usage: journal-facts.sh <YYYY-MM-DD> [source]}"
source_label="${2:-hook}"
PROJECTS="${POLARIS_JOURNAL_PROJECTS_DIR:-$HOME/.claude/projects}"
[ -d "$PROJECTS" ] || exit 0

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# GitHub costs network round trips, so the session-start hook skips it and /journal pays for it.
# Each call is capped when a timeout binary exists, so a hung API never blocks the caller.
timeout="$(command -v timeout || command -v gtimeout || true)"
[ -n "$timeout" ] && timeout="$timeout 20"
gh_ok=0
if [ "$source_label" != "hook" ] && command -v gh >/dev/null 2>&1 \
   && $timeout gh auth status >/dev/null 2>&1; then
  gh_ok=1
fi

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
    if [ "$gh_ok" = 1 ]; then
      prs="$(cd "$cwd" && $timeout gh pr list --state all --search "updated:$date" \
        --json number,title,state --template '{{range .}}#{{.number}} {{.state}} {{.title}}{{"\n"}}{{end}}' 2>/dev/null \
        | awk 'NF' | paste -sd';' - | sed 's/;/; /g')"
      [ -n "$prs" ] && printf -- '- PRs: %s\n' "$prs"
    fi
  fi
  artifacts="$(ls "$cwd"/.polaris/*/"$date"-*.md 2>/dev/null | sed "s|^$cwd/||" | paste -sd, - | sed 's/,/, /g')"
  [ -n "$artifacts" ] && printf -- '- Polaris artifacts: %s\n' "$artifacts"
  sweep_page="$(jq -r --arg d "$date" 'select((.lastRunAt // "") | startswith($d)) | .lastPageUrl // empty' \
    "$cwd/.polaris/work/sweep-state.json" 2>/dev/null)"
  [ -n "$sweep_page" ] && printf -- '- Sweep briefing: %s\n' "$sweep_page"
  printf '\n'
done < "$tmp/cwds"

# Cross-repo GitHub activity: PRs authored or reviewed and issues involving the user that day.
if [ "$gh_ok" = 1 ]; then
  gh_lines="$( { $timeout gh search prs --author=@me --updated="$date" --limit 30 \
                   --json repository,number,title --template '{{range .}}authored {{.repository.nameWithOwner}}#{{.number}} {{.title}}{{"\n"}}{{end}}' 2>/dev/null
                 $timeout gh search prs --reviewed-by=@me --updated="$date" --limit 30 \
                   --json repository,number,title --template '{{range .}}reviewed {{.repository.nameWithOwner}}#{{.number}} {{.title}}{{"\n"}}{{end}}' 2>/dev/null
                 $timeout gh search issues --involves=@me --updated="$date" --limit 30 \
                   --json repository,number,title --template '{{range .}}issue {{.repository.nameWithOwner}}#{{.number}} {{.title}}{{"\n"}}{{end}}' 2>/dev/null
               } | awk 'NF' | awk '!seen[$0]++')"
  if [ -n "$gh_lines" ]; then
    printf '## GitHub\n'
    printf '%s\n' "$gh_lines" | sed 's/^/- /'
    printf '\n'
  fi
fi

# Memory written that day: global Polaris entries and per-project auto-memory.
mem="$(find "$HOME/.claude/polaris-memory/entries" "$PROJECTS"/*/memory -type f -name '*.md' \
        -newermt "$date 00:00" ! -newermt "$date 23:59:59" 2>/dev/null \
        | sed "s|^$HOME/|~/|" | sort | paste -sd, - | sed 's/,/, /g')"
if [ -n "$mem" ]; then
  printf '## Memory\n'
  printf -- '- Written: %s\n' "$mem"
  printf '\n'
fi
