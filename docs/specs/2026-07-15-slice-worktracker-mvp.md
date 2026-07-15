# Slice: Work-Tracker MVP — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §8.4 (the flagship of subsystem E). Milestone M5.5.

The daily-pain win: you run many threads at once and lose track of what you were doing across
sessions. This MVP keeps the list for you, file-based, so nothing is lost. Full auto-maintenance
and semantic recall arrive with subsystem E.

## Problem

Work spans many parallel threads (UI, a bug, backend logic, a prototype, a new feature). Between
sessions the context is gone, and threads get dropped, sometimes until too late.

## Goal

A file-based work tracker that surfaces every open thread at session start and stays current with a
low-friction update, without the user maintaining it by hand.

### Success criteria

- `.polaris/work/streams.md` holds the open work streams in a fixed structure.
- The session-start hook injects the open streams every session, so each session begins by showing
  what is open and the next step for each.
- `/track` reconciles the current session into the streams: it adds new threads, updates status and
  next step, and closes finished ones, then writes the file back.
- The streams file passes the writing standard.

## Honest scope

Shell hooks cannot classify prose into work streams (that needs the model). So this MVP does the
deterministic part in hooks (surface the file) and the judgment part in a command (`/track`, model-
driven). The fully automatic, hook-driven maintenance and RAG recall described in §8.4 are
subsystem E, not this slice. This is the useful 20 percent that removes the daily pain now.

## Architecture

### The store

`.polaris/work/streams.md`. Each stream is a section:

```
## <id> — <title>
- domain: ui | ux | backend | bug | prototype | feature | infra | docs
- status: active | paused | blocked | done
- state: <one line: what is done / where it stands>
- next: <the single next concrete step>
- files: <key paths>
- touched: <date> (<session note>)
```

`templates/work-streams.md` ships the structure and one example.

### Surfacing (deterministic)

The `session-start` hook, when `.polaris/work/streams.md` exists, injects its active and blocked
streams into context under a clear header, so every session opens with "here is what is open and
the next step for each". Done streams are not surfaced.

### Update (model-driven)

`commands/track.md`: read `.polaris/work/streams.md` (create it from the template if absent) and
the current session's work, then reconcile: add any new thread, update the state and next step of
threads that moved, mark finished ones done, and flag any untouched for a while. Write the file
back. Keep it lean; do not let it grow unbounded (archive done streams to a `done` section or drop
them after noting completion). The file passes the writing standard.

### The guarantee

At any session start you see every open thread and its next step, so nothing is lost. Running
`/track` at the end of a work session keeps it true with one command.

## Testing and validation

- `templates/work-streams.md` and `commands/track.md` pass `check-patterns.sh prose`.
- The session-start change is syntax-checked and, with a sample `.polaris/work/streams.md`, is
  confirmed to inject the active streams (and skip done ones).

## Out of scope

- Hook-driven automatic classification, embeddings and RAG recall, the external mirror to
  Notion/Linear/Jira, and connectors. All of that is subsystem E (M6).
