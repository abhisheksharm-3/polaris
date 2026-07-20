# Spec — memory freshness markers + reconcile-by-body

## Problem

Polaris memory entries carry a `created` date but no *classification* of whether a fact stays true.
`rules/memory.md` "Retrieve" tells the reader to treat entries as "true when written" and "verify
before relying" — but that guidance is prose the model has to remember, not a per-entry signal recall
can act on. A version number saved six months ago and a timeless naming preference look identical.

Second, `/remember`'s duplicate check reads only `INDEX.md`'s one-line descriptions, so a near-duplicate
whose description is worded differently slips through and a second entry is created.

## Scope

In: a `freshness` frontmatter field on memory entries, recall acting on it, and `/remember` reconciling
against entry bodies. Out: the SessionEnd auto-capture hook (already covered by the session-start
journal + work-tracker reconcile — verified in `hooks/session-start`), and any frontmatter linter
(none exists for `type` either; freshness follows the same convention-only pattern).

## Design

New optional frontmatter field `freshness` on `~/.claude/polaris-memory/entries/<slug>.md`:

- `timeless` — durable, unlikely to change (a role, a naming convention, a hard preference). Default
  for `user` and `feedback`.
- `dated` — true as of `created`, may go stale (a version, a count, "currently uses X"). Recall must
  re-verify before relying, and note the age.
- `pointer` — the value lives in an external source (URL, dashboard, ticket, file path). Recall must
  check the source, not trust the stored copy.

A missing `freshness` reads as `timeless` (safe default — no nagging on legacy entries; additive, no
migration, consistent with the greenfield `backwardCompat: none` config).

`freshness` lives in the entry only, not in the `INDEX.md` line — the index is injected every session
and stays terse; recall opens the entry anyway.

## Changes

1. `rules/memory.md` — document `freshness` under a new bullet in "Store" and how "Retrieve" acts on
   it (dated → re-verify + age; pointer → check source; missing → timeless).
2. `commands/remember.md` — step: classify `freshness` alongside `type`; strengthen the reconcile step
   to `grep` entry bodies under `entries/`, not just scan `INDEX.md` descriptions.
3. `commands/recall.md` — when an opened entry is `dated` or `pointer`, surface it as needing
   verification (age for dated; re-check the source for pointer) instead of stating it as current fact.

## Acceptance criteria

1. `rules/memory.md` defines the three `freshness` values, the `timeless` default, and the recall
   behavior for each — with the missing-field default stated.
2. `commands/remember.md` sets `freshness` on every new entry and its duplicate check greps entry
   bodies, not only `INDEX.md`.
3. `commands/recall.md` distinguishes `dated`/`pointer` entries from current facts when answering.
4. `bash tests/run-tests.sh` stays green (no new dispatch lines or agents, so cross-ref checks hold).
5. Every edited line passes the writing standard.

## Non-goals

No change to `type`, the journal, the work tracker, or the session-start hook. No new file, script,
or dependency.
