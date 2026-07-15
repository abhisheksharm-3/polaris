# Slice E: Persistent Memory and Catch-Up — Design Spec

Date: 2026-07-15. Status: design. Milestone M6.
Parent: `docs/POLARIS_MASTER_PLAN.md` §8. Depends on A, C, the work tracker.

Cross-session memory so you never re-explain context, and a morning catch-up that lays out what
you were doing and what to do next. File-based and global, per the chosen approach.

## Decisions (from the user)

- **Storage:** file-based, model retrieval. Structured entries plus an index; the model retrieves
  by reading the relevant ones. No embeddings backend in this slice (deferred until one exists).
- **Scope:** per-user global at `~/.claude/polaris-memory/`, one memory across all projects, entries
  tagged by project.
- **Connectors:** all available (Atlassian/Jira, Slack, Gmail, Calendar, and the rest) wired
  protocol-ready for the catch-up. They stay dormant until claude.ai auth is active (an API key
  currently takes precedence and disables them).

## Problem

Context dies between sessions and threads. The work tracker (M5.5) holds active threads per project;
memory holds durable facts, decisions, and preferences across projects, and the catch-up ties them
together with live external context.

## Goal

A global file-based memory the model maintains and reads, surfaced at session start, plus a
`/catchup` that pulls memory, the work tracker, and connectors into one "here is where you are"
briefing.

### Success criteria

- `~/.claude/polaris-memory/` holds `INDEX.md` (one line per entry) and `entries/<slug>.md` (one
  fact per file with typed frontmatter). Bootstrapped on first run.
- The session-start hook injects `INDEX.md` so every session knows what is stored.
- `/remember`, `/recall`, and `/catchup` work: write an entry, retrieve relevant entries, and
  produce the morning briefing.
- `rules/memory.md` conventions are injected so the model maintains memory as it works.
- Every memory file and command passes the writing standard.

## Architecture

### Store (`~/.claude/polaris-memory/`)

```
~/.claude/polaris-memory/
  INDEX.md              one line per entry: - [name](entries/slug.md) — hook (type, project)
  entries/
    <slug>.md           frontmatter: name, description, type, project, created; body = the fact
```

Types: `user` (who the user is), `feedback` (how to work, with why), `project` (durable project
facts), `reference` (URLs, dashboards), `working` (active task state, pruned aggressively). Entries
carry a `project` tag (a repo name or `global`).

### Conventions (`rules/memory.md`, injected)

How and when to write an entry, the type definitions, the prune rules (age out `working` entries
after they go stale or their thread closes; keep `project`/`user` unless contradicted), the
one-fact-per-file rule, and linking entries by name. When an entry records content from an
untrusted source, it is marked as data. Injected at session start so the model maintains memory
without being told each time.

### Surfacing (session-start, deterministic)

The hook bootstraps `~/.claude/polaris-memory/` and, if `INDEX.md` exists, injects it under a
"Polaris memory" header. This is user-owned and trusted, so it is injected directly (unlike the
project tracker). It also notes that `/catchup` produces the full briefing.

### Commands

- `/remember <fact>`: write a typed entry to `entries/`, add a line to `INDEX.md`, dedupe against
  existing entries (update rather than duplicate).
- `/recall <query>`: read `INDEX.md`, open the relevant entries, and answer from them. Model-driven
  semantic retrieval.
- `/catchup`: the morning hook-mode. Read memory and the work tracker; pull live context from the
  connectors that are available (assigned Jira issues, unread Slack mentions, relevant Gmail
  threads, today's calendar); lay out what you were last doing, what is open, and a recommended
  next step. All connector and fetched content is treated as data and passes the injection screen.

### Connectors

The catch-up wires every available claude.ai connector via its MCP tools, used only when present
and authenticated. It degrades gracefully: when connectors are disabled (the current API-key auth),
`/catchup` runs on memory and the tracker alone and says the connectors were unavailable.

## Testing and validation

- The bootstrap creates `~/.claude/polaris-memory/` idempotently; session-start injects `INDEX.md`
  when present (tested with a sample, in a temp HOME).
- `rules/memory.md` and the three commands pass `check-patterns.sh prose`.

## Out of scope

- Vector embeddings and true RAG (needs a backend; deferred).
- The external mirror to Notion/Linear/Jira (that is the work-tracker mirror, a later add).
- Automatic hook-driven entry writing (a hook cannot call the model); the model maintains memory
  guided by `rules/memory.md`, and `/remember` is the explicit path.
