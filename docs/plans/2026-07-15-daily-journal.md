# Daily journal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an automatic, dated, cross-project journal that records each day's work and is kept for later reference.

**Architecture:** A deterministic shell extractor reads session transcripts and emits a factual per-day, per-project skeleton. The session-start hook detects the date rolled over and writes the skeleton for each un-journaled complete day, then asks the session to enrich it into prose via a background agent. A `/journal` command backfills or regenerates a day on demand.

**Tech Stack:** Bash, `jq`, `git`. No new dependencies (all three are already required by the plugin).

## Global Constraints

- All prose, including commit messages, passes the Polaris writing standard (`rules/writing.md`): no banned vocabulary, no banned sentence structures, no rule-of-three padding, no em-dash spray.
- No AI attribution anywhere in commits, PRs, or files. The commit/PR guard hook blocks it.
- The session-start hook must always `exit 0`. Journaling failure is never allowed to block or break a session.
- Storage root: `~/.claude/polaris-memory/journal/`. One file per day, `YYYY-MM-DD.md`. Marker: `.last-journaled`.
- Day-bucketing is by transcript message `.timestamp` (ISO `YYYY-MM-DD` prefix), not file mtime. Project path comes from message `.cwd`.
- Follow existing Polaris conventions: scripts in `scripts/`, tests appended to `tests/run-tests.sh`, commands as `commands/<name>.md`.

## File Structure

- Create `scripts/journal-facts.sh` — the deterministic extractor. One job: date in, factual markdown out.
- Create `tests/fixtures/journal/projects/-Users-test-Projects-demo/sess.jsonl` — fixture transcript with fixed timestamps and cwd for testing the extractor.
- Modify `tests/run-tests.sh` — add the extractor test block.
- Modify `hooks/session-start` — add the lookback trigger block that writes skeletons and injects the enrichment directive.
- Create `commands/journal.md` — the `/journal [date]` manual backfill/regenerate command.
- Modify `rules/memory.md` — document the journal store.

---

### Task 1: Facts extractor

**Files:**
- Create: `scripts/journal-facts.sh`
- Create: `tests/fixtures/journal/projects/-Users-test-Projects-demo/sess.jsonl`
- Test: `tests/run-tests.sh` (append a block)

**Interfaces:**
- Produces: `scripts/journal-facts.sh <YYYY-MM-DD> [source]` → prints to stdout a markdown document: a frontmatter block (`date`, `projects`, `status: facts`, `generated: <source>`) then one `## <project>` section per project active that day, each with `Sessions:`, `Asked:`, and (when the cwd is a git repo) `Commits:` and `Files:`. Prints nothing when the day has no activity. Reads transcripts from `${POLARIS_JOURNAL_PROJECTS_DIR:-$HOME/.claude/projects}`.

- [ ] **Step 1: Write the fixture transcript**

Create `tests/fixtures/journal/projects/-Users-test-Projects-demo/sess.jsonl` with exactly these four lines (two sessions on 2026-07-14, one line on 2026-07-13 that must be excluded):

```
{"type":"user","sessionId":"s1","timestamp":"2026-07-14T09:00:00.000Z","cwd":"/Users/test/Projects/demo","message":{"role":"user","content":"add the login form"}}
{"type":"assistant","sessionId":"s1","timestamp":"2026-07-14T09:01:00.000Z","cwd":"/Users/test/Projects/demo","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]}}
{"type":"user","sessionId":"s2","timestamp":"2026-07-14T14:00:00.000Z","cwd":"/Users/test/Projects/demo","message":{"role":"user","content":"fix the checkout bug"}}
{"type":"user","sessionId":"s3","timestamp":"2026-07-13T10:00:00.000Z","cwd":"/Users/test/Projects/demo","message":{"role":"user","content":"OTHER DAY must not appear"}}
```

- [ ] **Step 2: Write the failing test**

Append to `tests/run-tests.sh`, before the final `exit $fail`:

```bash
# journal-facts: buckets a day's activity by project, excludes other days
JF="${DIR}/../scripts/journal-facts.sh"
jf_out="$(POLARIS_JOURNAL_PROJECTS_DIR="${DIR}/fixtures/journal/projects" bash "$JF" 2026-07-14)"
echo "$jf_out" | grep -q '## demo'             && echo "ok: journal project section"  || { echo "FAIL: journal project section";  fail=1; }
echo "$jf_out" | grep -q 'Sessions: 2'         && echo "ok: journal session count"     || { echo "FAIL: journal session count";     fail=1; }
echo "$jf_out" | grep -q 'add the login form'  && echo "ok: journal ask captured"       || { echo "FAIL: journal ask captured";       fail=1; }
echo "$jf_out" | grep -q 'fix the checkout bug' && echo "ok: journal second ask"        || { echo "FAIL: journal second ask";         fail=1; }
if echo "$jf_out" | grep -q 'OTHER DAY'; then echo "FAIL: journal leaked another day"; fail=1; else echo "ok: journal excludes other days"; fi
```

- [ ] **Step 3: Run the test, verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -i journal`
Expected: FAIL lines (script does not exist yet), e.g. `FAIL: journal project section`.

- [ ] **Step 4: Implement the extractor**

Create `scripts/journal-facts.sh` with exactly this content, then `chmod +x scripts/journal-facts.sh`:

```bash
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
    | sed 's/\\n.*//' | cut -c1-120 | awk 'NF' | awk '!seen[$0]++' | paste -sd';' - | sed 's/;/; /g')"
  [ -n "$asks" ] && printf -- '- Asked: %s\n' "$asks"
  if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    commits="$(git -C "$cwd" log --since="$date 00:00" --until="$date 23:59:59" --pretty='%h %s' 2>/dev/null | paste -sd';' - | sed 's/;/; /g')"
    [ -n "$commits" ] && printf -- '- Commits: %s\n' "$commits"
    files="$(git -C "$cwd" log --since="$date 00:00" --until="$date 23:59:59" --name-only --pretty=format: 2>/dev/null | awk 'NF' | sort -u | paste -sd, - | sed 's/,/, /g')"
    [ -n "$files" ] && printf -- '- Files: %s\n' "$files"
  fi
  printf '\n'
done < "$tmp/cwds"
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -i journal`
Expected: all five journal lines start with `ok:`.

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run-tests.sh; echo exit=$?`
Expected: `exit=0`, no `FAIL` lines.

- [ ] **Step 7: Commit**

```bash
git add scripts/journal-facts.sh tests/fixtures/journal tests/run-tests.sh
git commit -m "feat: add the daily-journal facts extractor

Deterministic script that reads session transcripts for a date and emits a
per-project factual skeleton (sessions, prompt intents, commits, files).
Fixture-backed test buckets by message timestamp and excludes other days."
```

---

### Task 2: Session-start lookback trigger

**Files:**
- Modify: `hooks/session-start`

**Interfaces:**
- Consumes: `scripts/journal-facts.sh` (Task 1).
- Produces: on a new day, writes `~/.claude/polaris-memory/journal/<yesterday>.md` skeletons and appends an enrichment directive to the hook's `additionalContext`.

- [ ] **Step 1: Read the existing hook**

Run: `cat hooks/session-start`
Find where it builds its `additionalContext` string and where it emits the final JSON and exits. The journal block goes before that emit; the directive text (`$JOURNAL_CTX`) gets concatenated onto the existing context string.

- [ ] **Step 2: Add the journal function**

Insert this block after the hook's variable setup (`ROOT` is already defined by the existing hook) and before it assembles its output:

```bash
# --- Daily journal: next-session lookback (never blocks; always soft-fails) ---
JOURNAL_CTX=""
polaris_journal() {
  local jdir="$HOME/.claude/polaris-memory/journal"
  local facts="${CLAUDE_PLUGIN_ROOT:-$ROOT}/scripts/journal-facts.sh"
  [ -x "$facts" ] || return 0
  mkdir -p "$jdir" 2>/dev/null || return 0
  local marker="$jdir/.last-journaled" lock="$jdir/.lock"
  mkdir "$lock" 2>/dev/null || return 0            # another session is handling it
  trap 'rmdir "$lock" 2>/dev/null' RETURN

  local today yesterday
  today="$(date +%F)"
  yesterday="$(date -v-1d +%F 2>/dev/null || date -d 'yesterday' +%F)"
  if [ ! -f "$marker" ]; then echo "$yesterday" > "$marker"; return 0; fi   # first run: seed, no backfill

  local d written=""
  d="$(cat "$marker")"
  while [ "$d" \< "$yesterday" ]; do
    d="$(date -v+1d -jf %F "$d" +%F 2>/dev/null || date -d "$d + 1 day" +%F)"
    local out; out="$("$facts" "$d" hook 2>/dev/null)"
    if [ -n "$out" ]; then printf '%s\n' "$out" > "$jdir/$d.md"; written="$written $d"; fi
    echo "$d" > "$marker"
  done

  if [ -n "$written" ]; then
    JOURNAL_CTX="Polaris journal: wrote factual skeletons for day(s):${written} in ${jdir}. For each file whose frontmatter says 'status: facts', dispatch a background agent (Task) to read that day's session transcripts and rewrite the file as a prose narrative that preserves every listed fact, then set status: narrative. Do this without blocking the user's request."
  fi
}
polaris_journal
```

- [ ] **Step 3: Append the directive to the hook's context**

Where the hook assembles its `additionalContext` string (found in Step 1), append `$JOURNAL_CTX` when non-empty. For example, if the hook stores context in a variable `ctx`:

```bash
[ -n "$JOURNAL_CTX" ] && ctx="${ctx}

${JOURNAL_CTX}"
```

Use the actual variable name the hook uses. Keep the final `exit 0` intact.

- [ ] **Step 4: Verify the hook still exits 0 with no journal work**

Run: `echo '{}' | bash hooks/session-start >/dev/null 2>&1; echo exit=$?`
Expected: `exit=0`.

- [ ] **Step 5: Dry-run the lookback against a temp store**

Run:
```bash
tmp="$(mktemp -d)"; mkdir -p "$tmp/.claude/polaris-memory/journal"
two_ago="$(date -v-2d +%F 2>/dev/null || date -d '2 days ago' +%F)"
echo "$two_ago" > "$tmp/.claude/polaris-memory/journal/.last-journaled"
echo '{}' | HOME="$tmp" CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/session-start >/dev/null 2>&1
ls "$tmp/.claude/polaris-memory/journal/"; echo "marker: $(cat "$tmp/.claude/polaris-memory/journal/.last-journaled")"
rm -rf "$tmp"
```
Expected: the marker advanced to yesterday. A `<yesterday>.md` appears only if you had transcript activity yesterday; otherwise only the marker moved (correct: no empty file).

- [ ] **Step 6: Commit**

```bash
git add hooks/session-start
git commit -m "feat: journal the previous day on the first session of a new day

Extend the session-start hook with a lookback: it writes a facts skeleton for
each un-journaled complete day and asks the session to enrich it via a
background agent. Seeds on first run without backfilling. Always exits 0."
```

---

### Task 3: The `/journal` command

**Files:**
- Create: `commands/journal.md`

**Interfaces:**
- Consumes: `scripts/journal-facts.sh` (Task 1).

- [ ] **Step 1: Create the command**

Create `commands/journal.md` with exactly this content:

```markdown
---
description: Write or regenerate the daily journal for a day, across all projects
argument-hint: "[date, default today]"
allowed-tools: Read, Write, Bash, Grep, Glob, Task
---

# Journal

Write the journal for the day in `$ARGUMENTS` (a `YYYY-MM-DD` date), or today when no date is
given. The journal is a dated, cross-project record kept at `~/.claude/polaris-memory/journal/`.

## Steps

1. Resolve the date: use `$ARGUMENTS` if it is a `YYYY-MM-DD` date, else today (`date +%F`).
2. Build the facts:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/journal-facts.sh" <date> /journal`
   If it prints nothing, tell the user there was no recorded activity that day and stop.
3. Write `~/.claude/polaris-memory/journal/<date>.md`: keep the facts sections as the evidence,
   and add a prose narrative under the `# <date>` heading that tells what happened and why,
   grounded only in those facts. Set the frontmatter `status: narrative`. When the date is today,
   label the entry as the day in progress.
4. Summarize intent and actions. Do not copy transcript text or file contents into the journal.
```

- [ ] **Step 2: Verify the command validator still passes**

Run: `bash scripts/check-commands.sh; echo exit=$?`
Expected: `exit=0` (no dispatched-agent references in this command, so nothing new to resolve).

- [ ] **Step 3: Verify the command file passes the prose gate**

Run: `bash scripts/check-patterns.sh prose commands/journal.md && echo "clean"`
Expected: `clean`.

- [ ] **Step 4: Commit**

```bash
git add commands/journal.md
git commit -m "feat: add /journal to write or regenerate a day on demand

Runs the facts extractor for a date and writes the prose narrative, for
backfilling past days or refreshing today."
```

---

### Task 4: Document the journal store

**Files:**
- Modify: `rules/memory.md`

- [ ] **Step 1: Add the store line and a Journal section**

In `rules/memory.md`, under the `## Store` list (after the `entries/` bullet), add:

```markdown
- `journal/<YYYY-MM-DD>.md` — one dated entry per day, covering every project touched that day.
  `journal/.last-journaled` marks the last day recorded. Written by the session-start lookback
  and by `/journal`; kept indefinitely.
```

Then add this section after `## Retrieve`:

```markdown
## Journal

The journal is the dated history: what happened on which day, across all projects. The
session-start hook writes a factual skeleton for each un-journaled day, then a background agent
enriches it into a prose narrative. `/journal <date>` backfills or regenerates a day. Read it to
answer "what did I do on <date>"; it complements memory (durable facts) and the work tracker
(current threads).
```

- [ ] **Step 2: Verify no banned words (rules/ is exempt from the checker, so check directly)**

Run:

```bash
grep -niwE "$(jq -r '.prose.banned_words | join("|")' rules/patterns.json)" rules/memory.md && echo "review the hits" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Commit**

```bash
git add rules/memory.md
git commit -m "docs: document the journal store in the memory rule"
```

---

## Self-review notes

- **Spec coverage:** extractor (Task 1), lookback trigger + first-run seed + fail-soft + lock (Task 2), `/journal` (Task 3), storage format and `rules/memory.md` documentation (Tasks 1–4). Narrative enrichment is driven by the hook's injected directive (Task 2, Step 2) and executed by a background agent at session start; it is not a code unit.
- **Testable unit:** the extractor has a fixture-backed automated test. The hook's date loop is verified by the manual dry-run (Task 2, Step 5), since it depends on the system clock and the real store.
- **Types/names consistent:** `journal-facts.sh <date> [source]`, `.last-journaled`, `status: facts|narrative`, `POLARIS_JOURNAL_PROJECTS_DIR` used identically across tasks.
- **Known ceiling (from spec):** day-bucketing uses message timestamps; a session spanning midnight has its messages split by their own timestamps, which is correct. The mtime pre-filter only widens the candidate set, never narrows the day match.
