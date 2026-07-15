# Polaris revamp — Feature Handoff

> To the thread picking this up: this captures in-progress work so you continue without losing
> anything. Read it top to bottom. Where a section says "none", that is real, not missing.

Date: 2026-07-15. Branch: main.

## What this is

Polaris is being revamped from a design/quality plugin into an all-in-one project operating system
for Claude Code: the full SDLC plus product, research, marketing, and ops, held to one quality bar
with anti-slop writing enforced on every line of output. The full vision is in
`docs/POLARIS_MASTER_PLAN.md`; it is built as milestones M1 through M6.

## Current status

M1 (the quality foundation) and M2 (handoff and audit docs) are built, tested, and committed to
main. The plugin is at version 0.3.0, moving to 0.4.0 with this slice. The deterministic checker
and the commit-guard hook have passing shell tests; the checker was validated on the real
sage-frontend repo (1,359 findings across 80 files).

## What is done (with evidence)

- **M1 / Slice A** (commits `1683770` through `a9dc606`): the canonical standard (`rules/core.md`,
  `rules/writing.md`, `rules/patterns.json`, `rules/stack-map.json`, six stack overlays), the
  `quality-gate` skill and `/gate`, the `polaris-writing` output style, `guard-commit-pr` and
  `guard-edit` hooks, the setup interview and companions, and the merged `code-cleanup` and
  stack-aware `audit-refactor`. Retired `general.md`, `no-ai-slop.md`, `slop-remover.md`.
- **M2 / Slice C** (commits `2825e8c` through this one): `rules/doc-organization.md`, the feature
  and audit handoff templates, the `/handoff` command, and the strict `prod-audit` agent.
- Tests green: `bash tests/run-tests.sh` passes six checks.

## What remains

1. **M3 — Subsystem B core + model routing (J) + guardrails (I).** The agent fleet across SDLC
   roles, the model-routing policy (Opus for planning/QA/review, Sonnet for code, Haiku trivial),
   and the prompt-injection `PostToolUse` classifier. Start from master plan §6, §6.3, §4.3.
2. **M4 — Subsystem D (the orchestration cycle) + G (standalone modes).** The idea-to-shipped loop
   as chained workflows, and task-scoped modes. Master plan §5, §6.1.
3. **M5 / M5.5 — F (prompt enhancing) + H (dynamic synthesis) + the work-tracker MVP.** The
   work-tracker (master plan §8.4) is a high-value early win the owner wants.
4. **M6 — E (persistent memory + connectors).**

## How to continue (read these first, in order)

1. `docs/POLARIS_MASTER_PLAN.md` — the whole vision, decisions, and milestones.
2. `docs/specs/2026-07-03-slice-a-quality-foundation.md` and
   `docs/specs/2026-07-04-slice-c-handoff-audit-docs.md` — the built slices.
3. The memory entries `polaris-revamp` and `work-on-main`.
4. `rules/core.md` and `rules/writing.md` — the standard everything is held to.

## Decisions locked

- All work stays on main; no feature branches (owner's rule).
- Stack knowledge comes from the skill library plus fresh docs, not hand-written modules.
- Companions install via native plugin dependencies plus a first-run skill sync.
- Model routing: Opus is the floor for planning, QA, interview, and review; Sonnet writes code;
  Haiku only for the trivial.
- The injection classifier leans on Claude Code's auto-mode classifier first; Polaris adds a
  PostToolUse pass for untrusted content into agents and memory.

## Gotchas

- The Bash tool runs zsh, which does not word-split unquoted `$var`. Pass file lists to
  `check-patterns.sh` as separate args (or via `xargs`), never as one unquoted variable.
- The checker skips `rules/` and `patterns.json` (they hold banned patterns as data).
- Plugin agents ignore `hooks`, `mcpServers`, and `permissionMode` frontmatter; rely on
  session-level config for those.

## Definition of done

- [ ] M3 through M6 built, each with its own spec and plan, each milestone independently useful.
- [ ] The full orchestration cycle takes an idea to a reviewed, tested, CI-green change.
- [ ] Every emitted line (code, commits, PRs, docs) passes the gate and the writing standard.
