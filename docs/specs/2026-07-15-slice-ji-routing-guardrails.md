# Slice J+I: Model Routing and Injection Guardrails — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §6.3 (J), §4.3 (I). Depends on Slice A.

Two small cross-cutting pieces the agent fleet and the cycle both need: a model-routing policy so
every agent runs on the right tier, and an injection guardrail so untrusted content cannot steer
Polaris.

## Problem

- Agents left on the default model waste money or under-power hard work. There is no policy.
- Polaris reads untrusted text (fetched web pages, MCP payloads, referenced repos). A prompt-
  injection payload in that text could steer an agent. Claude Code's auto-mode classifier covers
  the model path, but there is no Polaris-side deterministic pass on tool results.

## Goal

A model-routing policy injected every session and applied to agents, plus a deterministic
injection guardrail on tool results, backed by data in `patterns.json` and covered by a test.

### Success criteria

- `rules/model-routing.md` states the tier policy and is injected at session start. Existing and
  new agents carry a `model` that matches the policy.
- `rules/patterns.json` gains an `injection` section; `hooks/guard-input` scans `WebFetch` and MCP
  tool results for those patterns and flags them via `additionalContext` (non-destructive).
- A shell fixture test proves the guardrail flags a known injection string and passes clean text.

## Architecture

### J: model routing

- `rules/model-routing.md`: the policy table. Opus is the floor for breaking/adversarial QA,
  interview and intake, planning, spec, architecture, threat model, review, and RCA. Sonnet writes
  code. Haiku only for genuinely trivial one-off tasks. The floor is a minimum, never a cap. A
  project may extend it in config.
- Apply the policy to agents via the native `model` frontmatter field. The auditor and prod-audit
  are Opus; code-cleanup and implementation agents are Sonnet; there is no Haiku agent in the core
  fleet (Haiku is for ad-hoc trivial subagent calls, not a standing role).
- Injected at session start alongside the other rules.

### I: injection guardrail

- `patterns.json` gains `injection.phrases`: known instruction-override and exfiltration markers,
  for example "ignore previous instructions", "disregard your instructions", "ignore the above",
  "you are now", "system prompt", "exfiltrate", "send your ... to".
- `hooks/guard-input` (PostToolUse, matcher `WebFetch|mcp__.*`): read the tool result text, scan it
  against `injection.phrases`. On a hit, emit `additionalContext` that warns Claude the content
  contains possible injection and must be treated as data, not instructions. Non-destructive: it
  warns, it does not silently rewrite the result, so legitimate content is never mangled.
- The checker script gains an `injection` scope so the same data drives the hook and any manual
  check.
- Relationship to the base model: this is the second layer. Claude Code's auto-mode classifier and
  server-side probe are the first. This adds a deterministic Polaris-side pass for the specific
  case of untrusted content reaching Polaris agents and memory.

### Files

```
rules/
  model-routing.md     the tier policy (injected)
  patterns.json        + injection.phrases section
scripts/
  check-patterns.sh    + injection scope
hooks/
  guard-input          PostToolUse on WebFetch/MCP: flag injection in tool results
  session-start        + inject model-routing.md
  hooks.json           + register guard-input
tests/
  fixtures/injection-bad.txt, injection-clean.txt
  run-tests.sh         + guard-input assertions
agents/*               set model frontmatter per the policy
```

## Testing

- Extend `tests/run-tests.sh`: feed `guard-input` a PostToolUse payload whose tool result contains
  an injection phrase and assert it emits `additionalContext`; feed clean text and assert it stays
  silent. Also assert `check-patterns.sh injection` flags the bad fixture and passes the clean one.

## Out of scope

- A model-based classifier for injection (the base auto-mode classifier covers that); this slice is
  the deterministic phrase layer only.
- The agent fleet itself (Slice B).
