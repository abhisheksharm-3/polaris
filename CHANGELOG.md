# Changelog

All notable changes to Polaris. Dates are release dates; the format follows semantic versioning.

## 1.3.0 — 2026-07-19

Adapt ideas from `mattpocock/skills` and `ayghri/i-have-adhd` (both MIT) into Polaris-native form.
A gap analysis kept only what Polaris did not already do: most of the source skills duplicated
existing agents and commands, so the work adds four new pieces and folds the rest into what exists.

New:

- `/recon` — plan a large, foggy effort as a shared decision map of open questions before any spec
  or code. Typed decision tickets (research, grilling, prototype, task), a frontier of unblocked
  tickets, and one decision per session. Runs before `/flow`.
- `/domain` — model the domain into a ubiquitous-language glossary (`CONTEXT.md`) and a numbered
  `docs/adr/` decision ledger, written inline as terms resolve, with a three-gate filter on what
  earns an ADR.
- `/route` — route a situation to the one right Polaris command and say why.
- `merge-conflicts` skill — resolve an in-progress merge or rebase by intent, hunk by hunk, running
  the quality gate before finishing.

Folded into existing agents and commands:

- `product`: the spec now names its testing seams, resolves facts by looking them up instead of
  asking, and captures domain terms into the glossary as they settle.
- `reviewer` and `/review-pr`: a spec-conformance lens that checks the diff against acceptance
  criteria as an axis separate from the quality lenses.
- `architect`: a three-gate ADR filter and a numbered `docs/adr/` ledger.
- `audit-refactor`: rank targets by git churn before the full scan.
- `/triage`: a `ready-for-agent` versus `ready-for-human` lifecycle state.
- `/handoff`: a secret and PII redaction pass, plus a suggested-skills line.
- `/onboard`: a resumable learner-progress ledger across sessions.
- The writing standard and output style: an answer-first response shape.

## 1.2.3 — 2026-07-16

- Escape the session-start context with `jq` instead of bash, cutting startup from 19 seconds to 0.4.

## 1.2.2 — 2026-07-16

- Add `/journal`: write or regenerate a day's journal on demand, with automatic journaling of the
  previous day on the first session of a new day, backed by a daily-facts extractor.
- Auto-maintain the work tracker and log every `/flow` run.
- Give every agent a role-specific Expertise section.
- Add a craft-principles rule, injected every session.
- Extend the quality gate to Python, Go, and Rust, and harden the injection screen.
- Run the test suite on every push and pull request.
- Fix the session-start crash and the 30-second startup hang: run the companion install once rather
  than on every session, with regression tests and a recorded RCA.
- Add the missing `/audit` command and stop linting code fences as prose.

## 1.2.1 — 2026-07-15

- Add a "Using Polaris" guide to the README: the platform organized by job, not by tool, with the
  one command to run for each situation and how to get the best result from it (ship a feature, fix
  a bug, check work before it ships, understand or clean up a codebase, harden and upgrade, plan and
  triage, release, stay oriented across sessions).

## 1.2.0 — 2026-07-15

Seven operational modes that ride the fleet, gate, and guardrails:

- `/modernize` (dependency and framework upgrades), `/harden` (security pass), `/review-pr` (review
  an existing PR), `/triage` (classify a batch of bugs or issues), `/release` (cut a release),
  `/docs-drift` (fix docs that no longer match the code), and `/spike` (a timeboxed throwaway
  prototype to answer a feasibility question).

## 1.1.0 — 2026-07-15

- Add `/debug`, the bug lifecycle: an intake interview, grounding in the code and the stack (fresh
  docs and the DB schema), a real reproduction, root-cause analysis that names the class of bug, a
  class-level fix, verification, a regression test, and an RCA. The bug counterpart to `/flow`.
- Add `/incident`: production incident to blameless postmortem, stabilize before diagnosing.
- Forbid AI attribution in commits, PRs, and code (no `Co-Authored-By` for the AI, no
  "generated with" byline); the commit hook enforces it.
- Wire skill resolution to the sources: installed skills, marketplace companions, then the discovery
  registries filtered by security grade. Add the ponytail companion and its laziness ladder.
- Rewrite the README as the full front door.

## 1.0.0 — 2026-07-15

First stable release. Polaris is now an all-in-one project operating system for Claude Code: the
full SDLC plus product, research, marketing, and ops, held to one quality bar with anti-slop prose,
built across ten subsystems. This release also:

- Deepens all 27 fleet agents from thin stubs into senior-practitioner definitions with concrete
  per-role checklists, failure modes, and techniques.
- Adds the **ponytail** minimalism companion and its laziness ladder to the standard, so code
  writers build the least code that works; it auto-injects into every subagent.
- Adds `rules/routing.md`, a task classifier that maps each task to the agent, command, ponytail
  intensity, and model tier to use.
- Completes `companions.json` as the full manifest of every marketplace, plugin, skill source, and
  discovery registry.
- Fixes the SessionStart hook permission error by making the hook scripts executable.

Everything below shipped in the lead-up to this release.

## 0.11.0 — Dynamic agent synthesis (H)

- `/synthesize`: compose an ephemeral agent from the skill registries for a task no fleet agent
  covers, with a security-grade trust filter and the injection guardrail applied.

## 0.10.0 — Persistent memory (E)

- Global file-based memory at `~/.claude/polaris-memory/` with `rules/memory.md` conventions,
  session-start bootstrap and surfacing, and `/remember`, `/recall`, `/catchup`.
- `/catchup` briefs across memory, the work tracker, and connectors (wired protocol-ready).

## 0.9.0 — Prompt enhancing (F)

- A gated judge-then-enhance `UserPromptSubmit` hook (off by default) and `/enhance`.

## 0.8.0 — Work tracker (E flagship, MVP)

- `.polaris/work/streams.md` surfaced at session start, updated by `/track`, screened for injection.

## 0.7.0 — Orchestration cycle and standalone modes (D, G)

- `/flow`: the idea-to-shipped cycle across the fleet, gated at spec, design, and plan, with capped
  verify loops.
- `/research`, `/onboard`, `/explain` standalone modes. A command-to-agent reference check.

## 0.6.0 — Agent fleet (B)

- 27 role agents across every SDLC phase and domain, each following one contract, wiring skills, and
  carrying a model tier. An agent-frontmatter validator.

## 0.5.0 — Model routing and injection guardrail (J, I)

- `rules/model-routing.md` and matching agent tiers.
- `guard-input`: flags prompt-injection markers in fetched and MCP tool results.

## 0.4.0 — Handoff and audit docs (C)

- `/handoff` (feature and audit variants), the strict `prod-audit` agent, and the enforced
  `.polaris/` doc layout.

## 0.3.0 — Quality foundation (A)

- One canonical standard (`core.md`, `writing.md`, stack overlays, `patterns.json`), the
  `quality-gate` skill and `/gate`, the writing output style, the commit/PR and edit guards, the
  setup interview and companions. Merged the cleanup agents; retired the legacy rule files.

## 0.2.0 and earlier

- The original design-intelligence plugin: UI skills, stack detection, and the first quality agents.
