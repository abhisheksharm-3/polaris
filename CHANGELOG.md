# Changelog

All notable changes to Polaris. Dates are release dates; the format follows semantic versioning.

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
