# Flow enforcement, Task 6 preflight

Date: 2026-08-01. Plan: `docs/plans/2026-08-01-flow-enforcement.md`, Task 6.

The installed plugin was 1.8.0 against a repo at 1.9.0 plus nine unpushed commits, so no hook in
tasks 1 through 5 had ever run under its real path. The working tree was synced into
`~/.claude/plugins/cache/polaris-marketplace/polaris`, with the 1.8.0 copy kept alongside as
`polaris.bak-1.8.0`. Nothing was pushed.

## What the preflight proves

Every hook was driven with a hand-built payload, with `CLAUDE_PLUGIN_ROOT` set to the installed
copy rather than the repo, so the paths under test are the ones a session would use.

| Check | Result |
|---|---|
| A bug description routes to the `bug` flow and opens the run at `reproduce` | pass |
| A dispatch to `backend` during `reproduce` is denied, naming the phase and the agent it wanted | pass |
| A dispatch to `bug-fixer` during `reproduce` is allowed | pass |
| A turn ending mid-phase is blocked, naming the phase and how to record it | pass |
| A second turn ending on the same phase is silent | pass |
| A question in a clean project routes nowhere and writes no ledger | pass |

## What it does not prove

Claude Code firing the hooks at all. The matcher strings, the event names, and the payload field
names are read from the hooks reference, not observed. `guard-phase` reads
`tool_input.subagent_type`; if the Task tool names that field differently, every check above still
passes here and the gate silently allows everything in a real session.

That is the whole point of the live pass, and it needs a session started after the sync.

## Open

The live pass itself. Until it runs, treat the enforcement as tested, not proven.
