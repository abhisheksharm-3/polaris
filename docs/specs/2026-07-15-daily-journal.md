# Daily journal

Spec. Date: 2026-07-15. Status: approved for planning.

## Problem

Polaris keeps three kinds of state, and none of them is a dated historical record:

- **Global memory** (`~/.claude/polaris-memory/`) holds durable facts, not a day-by-day log.
- **The work tracker** (`.polaris/work/streams.md`) holds current open threads, overwritten as
  work moves. It answers "where am I now", not "what happened on the 12th".
- **Handoffs** are point-in-time continuation docs, written on request.

There is no way to ask "what did I do on 2026-07-11". Work spread across many sessions and projects
in a day leaves no single trace once the tracker moves on. This feature adds that trace.

## Goals

- One journal entry per calendar day, covering every project touched that day.
- Generated automatically, without an always-on process.
- Detailed: a prose narrative of the day plus the hard facts behind it.
- Stored where Polaris can reference it later, kept indefinitely.

## Non-goals

- No live/real-time logging during a session.
- No pruning or expiry. Entries are small and kept.
- No cross-machine sync. This is local to `~/.claude/`.
- Not a replacement for the work tracker or memory. It sits beside them.

## Decisions (settled in brainstorming)

| Decision | Choice | Reason |
|---|---|---|
| Trigger | Next-session lookback | No daemon exists. The first session on a new day journals the day(s) before it. Catches up if days are skipped. |
| Scope | Global, all projects | "All work across all sessions" spans projects. One file per day. |
| Storage | `~/.claude/polaris-memory/journal/` | Lives in the global memory store, so `/recall` and `/catchup` can read it. |
| Detail | Auto full narrative | User wants prose, not only facts. |
| Mechanism | Facts skeleton (hook) + narrative (background agent) | The skeleton is captured deterministically and always survives; the narrative enriches it without blocking the session. |

## Architecture

Four units, each with one job.

### 1. `scripts/journal-facts.sh <date>`

Pure deterministic extractor. Input: a date (`YYYY-MM-DD`, local). Output: a factual markdown
skeleton on stdout.

- Projects directory is `${POLARIS_JOURNAL_PROJECTS_DIR:-$HOME/.claude/projects}` (the override
  makes it testable with a fixture directory).
- Scan every `*.jsonl` transcript in that directory. Select message lines whose `.timestamp`
  starts with the date string. Bucket by `.cwd` (the exact repo path; no directory-name decode).
- Per project (per distinct `cwd` with activity that day) emit:
  - **Sessions:** count of distinct `.sessionId` values active that day.
  - **Asked:** the first line of each `type == "user"` message's text, truncated to 120 chars,
    de-duplicated, in order.
  - **Commits:** if `cwd` is a git repo, `git -C <cwd> log --since=<date> 00:00 --until=<date+1>
    00:00 --pretty='%h %s'` (author-date within the day).
  - **Files:** names changed by those commits (`--name-only`, unique).
- Emit nothing for a project with no day activity. Emit a non-zero body only when the day has
  activity.
- Output shape: the frontmatter block (`date`, `projects`, `status: facts`) followed by the
  per-project sections. The caller passes a source label for the `generated` field (`hook` or
  `/journal`).

Depends on: `jq`, `git`, the transcripts directory.

### 2. `hooks/session-start` (extend the existing hook)

Date-rollover detector and trigger. Added after the current session-start behavior. Never blocks
or errors a session: all journal work is guarded and the hook always exits 0.

- Marker: `~/.claude/polaris-memory/journal/.last-journaled`, one line, the last date whose
  skeleton was written.
- `today = date +%F`. Complete days needing a journal are `marker+1 .. today-1` (today is still in
  progress and is not journaled).
- **First run** (no marker): seed the marker to yesterday and skip backfill. A cold start must not
  process the whole history. Older days are available on demand through `/journal <date>`.
- For each missing complete day D with activity: run `journal-facts.sh D` into
  `journal/D.md` with frontmatter `status: facts`. Advance the marker to the newest D processed.
- If any skeletons were written, inject `additionalContext`: name the files with `status: facts`
  and instruct the session to dispatch a background agent that enriches each into a prose
  narrative preserving the listed facts, then set `status: narrative`. The directive says to do
  this without blocking the user's request.
- Concurrency: two sessions starting the same morning race on the marker. Guard with an `mkdir`
  lock around the write; if the lock is held, skip (the other session is handling it). A rare
  double-write is harmless because the skeleton write is idempotent.

### 3. `commands/journal.md` — `/journal [date]`

Manual backfill and regenerate. `argument-hint: "[date]"`, `allowed-tools: Read, Write, Bash,
Grep, Glob, Task`.

- Resolve the date: the argument, or today.
- Run `journal-facts.sh <date>` to build or refresh the facts.
- Write the full prose narrative to `journal/<date>.md`, `status: narrative`, preserving the
  facts. For today, label it partial ("day in progress").

### 4. Storage and format

`~/.claude/polaris-memory/journal/`:

- `YYYY-MM-DD.md` — one per day.
- `.last-journaled` — the marker.

File format:

```
---
date: 2026-07-15
status: facts        # or: narrative
projects: [polaris, sage-frontend]
generated: hook      # or: /journal
---

# 2026-07-15

<narrative prose, written on enrichment; absent while status is facts>

## polaris
- Sessions: 3
- Asked: init; enhance (x3); research what to build; add a daily journal feature
- Commits: 7c34d6f seven operational modes; 5ec29f5 debug and incident modes
- Files: rules/core.md, scripts/check-patterns.sh, ...

## sage-frontend
- Sessions: 1
- Asked: ...
```

`rules/memory.md` gains one line in its Store section pointing at the journal, and a short
paragraph describing it.

## Data flow

Day N: work happens across projects. Day N+1, first session on any project starts. The hook sees
`marker = N-1 < N`, runs the extractor for day N, writes `N.md` (status: facts), advances the
marker to N, and injects the enrichment directive. The session dispatches a background agent that
reads day N's transcripts, writes the narrative into `N.md`, and flips status to narrative. The
user's own request proceeds in parallel.

## Error handling (fail-soft)

- No transcripts or no activity for a day: write no file, still advance the marker past it.
- `cwd` is not a git repo: omit the commits and files lines for that project; sessions and asks
  still record.
- Extractor or enrichment failure: the hook still exits 0; a skeleton without a narrative is an
  acceptable result and can be regenerated with `/journal`.
- The narrative step never runs (directive ignored, session ends early): the factual skeleton
  remains as the record.

## Secrets ceiling

The extractor records prompt first lines and commit subjects, never file contents. The narrative
summarizes intent and actions rather than copying transcript text. This reduces, but does not
remove, the chance that a secret typed into a prompt reaches the journal. Accepted: the data is
local to the user's own machine. Documented so the tradeoff of the auto-narrative choice is
explicit.

## Testing

`journal-facts.sh` is the unit under test. A fixture directory
`tests/fixtures/journal/projects/<encoded>/<uuid>.jsonl` holds transcript lines with fixed
timestamps and `cwd` values for a known date. The test sets `POLARIS_JOURNAL_PROJECTS_DIR` to the
fixture and asserts the extractor's output contains the expected sessions, asks, and project
sections for that date, and excludes activity from other dates. Added to `tests/run-tests.sh`.

## Acceptance criteria

- On the first session of a new day, yesterday's `journal/<date>.md` exists with a facts skeleton,
  and the marker advanced. A later session the same day does not regenerate it.
- The file names every project active yesterday, with correct session counts, prompt intents, and
  commits per project.
- A background agent turns the skeleton into a prose narrative that keeps the facts, and sets
  status to narrative.
- `/journal 2026-07-14` regenerates that day on demand.
- The hook never blocks or errors a session; a failure leaves at most a facts-only skeleton.
- `bash tests/run-tests.sh` passes, including the new extractor test.
