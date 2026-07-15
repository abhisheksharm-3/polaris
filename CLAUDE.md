# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Behavioral Rules

These rules apply to every task unless explicitly overridden.
Bias: caution over speed on non-trivial work.

### Rule 1 — Think Before Coding
State assumptions explicitly. Ask rather than guess.
If multiple interpretations exist, present them — don't pick silently.
Push back when a simpler approach exists. Stop when confused.

### Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
No "flexibility" or "configurability" that wasn't requested.
If you write 200 lines and it could be 50, rewrite it.

### Rule 3 — Surgical Changes
Touch only what you must. Don't improve adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.
Remove imports/variables/functions that YOUR changes made unused.
Don't remove pre-existing dead code unless asked.

### Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
For multi-step tasks, state a brief plan with numbered steps before touching code.
Strong success criteria let Claude loop independently.

### Rule 5 — Use the Model Only for Judgment Calls
Use for: classification, drafting, summarization, extraction.
Do NOT use for: routing, retries, deterministic transforms.
If code can answer, code answers.

### Rule 6 — Token Budgets Are Not Advisory
If a session is spiraling or re-suggesting rejected fixes, summarize and start fresh.
Surface the breach. Do not silently overrun.

### Rule 7 — Surface Conflicts, Don't Average Them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup. Don't blend conflicting patterns.

### Rule 8 — Read Before You Write
Before adding code, read exports, immediate callers, shared utilities.
If unsure why existing code is structured a certain way, ask.

### Rule 9 — Tests Verify Intent, Not Just Behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

### Rule 10 — Checkpoint After Every Significant Step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back. If you lose track, stop and restate.

### Rule 11 — Match the Codebase's Conventions, Even if You Disagree
Conformance > taste inside the codebase.
If you think a convention is harmful, surface it. Don't fork it silently.

### Rule 12 — Fail Loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

---

## Project

Polaris is a Claude Code plugin: an all-in-one project operating system that runs the software
lifecycle under one quality standard. It is markdown-and-shell driven — no compiled code, no
package manager. The plugin dogfoods its own standard: the rules it enforces on your code, it
enforces on itself.

## Commands

| Command | Description |
|---------|-------------|
| `bash tests/run-tests.sh` | Full test suite: pattern checks, commit/PR guard, injection guard against fixtures |
| `bash scripts/check-patterns.sh <prose\|code\|injection> <file>` | Run one deterministic pattern check (exit 1 = flagged) |
| `bash scripts/check-agents.sh` | Validate agent definitions in `agents/` |
| `bash scripts/check-commands.sh` | Validate command definitions in `commands/` |
| `bash scripts/ensure-companions.sh` | Idempotent companion-plugin installer (no-op after first run) |

## Architecture

- `agents/` — the SDLC agent fleet (product, architect, backend, reviewer, tester, shipper, …)
- `commands/` — slash-command entry points (`/flow`, `/debug`, `/gate`, `/audit`, …)
- `skills/` — bundled skills (quality-gate, ui-new, ui-polish, ui-prototype, playwright-e2e)
- `hooks/` — session-start, commit/PR guard, tool-result injection guard
- `rules/` — the standard: `core.md`, `writing.md`, `patterns.json`, plus per-stack overlays in `stacks/`
- `scripts/` — deterministic check runners and the companion installer
- `output-styles/` — the Polaris writing output style
- `templates/` — config and doc templates (e.g. `config.default.json`)
- `docs/` — `plans/` and `specs/` for in-progress work
- `.polaris/` — per-project config (`config.json`), `work/`, `handoffs/`

## Gotchas

- No build or lint step — the "build" is the shell checks in `scripts/` and `tests/`.
- The writing standard (`rules/writing.md`) applies to ALL prose, including commit messages and PR
  bodies. Banned words and structures are enforced by the commit/PR guard hook.
- AI attribution in commits and PRs is forbidden and blocked by the guard hook.
- `.polaris/config.json` drives the gate, hooks, and every agent. Changing it changes enforcement.
- Version lives in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` — bump both.
