# Polaris Master Plan

Status: living document. Last updated 2026-07-03.

This is the single source of truth for what Polaris is becoming. Read this first in any
new session. It captures the full vision, the decisions already made, the build order, and
the status of each piece, so the plan never has to be re-explained from scratch.

Per-slice implementation specs live in `docs/specs/`. This document links to them as they
are written.

---

## 1. What Polaris is

Polaris today is a design-intelligence and stack-aware quality layer for Claude Code: a few
quality agents, four UI skills, an anti-slop ruleset, and a session-start hook that detects
the stack and injects rules.

Polaris is becoming an opinionated, end-to-end engineering system for Claude Code. It takes
a feature from a rough idea to a merged, CI-green pull request, and it holds one quality bar
across every step: the code it produces is simple, performant, secure, self-explanatory, and
low in complexity, and every line of prose it emits (comments, commit messages, PR text,
docs) reads like a careful human wrote it, not an LLM.

The north star: you should be able to hand Polaris a PRD or a vague idea, answer its
questions, approve its spec and plan, and get back a reviewed, tested, CI-green PR built to a
standard you did not have to police by hand.

---

## 2. Core philosophy (the bar)

Every subsystem stands on these. They are constraints, not suggestions.

### 2.1 The code bar

- **Simple first.** The minimum code that solves the problem. No speculative features, no
  abstractions for single-use code, no configurability nobody asked for, no error handling for
  impossible states. If 200 lines could be 50, it is 50. (Karpathy 2.)
- **Root cause, not symptom.** When a bug is found, fix the logic that caused the whole class
  of bug so it never recurs. Never make a test pass with a hardcode, a hacky patch, or an
  anti-pattern. Never treat the symptom.
- **Self-explanatory.** Names carry the meaning. Comments explain WHY only, never WHAT. JSDoc
  or the language's doc convention on exported surfaces, nothing else.
- **Secure and performant by default.** Validate at boundaries, never trust external input,
  no N+1s, no obvious footguns. The exact checks come from the stack skill plus fresh docs.
- **No workarounds, ever.** If it cannot be done correctly, stop and say why. No `TODO: fix
  later`, no `as any`, no swallowed errors, no compatibility shims.

### 2.2 The prose bar

Every line of natural language Polaris emits passes the anti-slop writing standard
(`rules/writing.md`): no banned LLM vocabulary, no "not only X but Y", no rule-of-three
padding, no significance inflation, no em-dash spray, no "challenges and future" closer. This
applies to code comments, commit messages, PR titles and bodies, and every doc, with no
exception. This document is written to that standard as a reference.

### 2.3 Karpathy's mode-dependent rule

Karpathy's guidelines (think before coding, simplicity first, surgical changes, goal-driven
execution) power the whole system. One of them, surgical changes, appears to conflict with
Polaris's aggressive-cleanup stance. They resolve by mode:

| Mode | Rule that governs |
|---|---|
| Feature implementation | **Surgical.** Touch only what the task requires. Every changed line traces to the request. Do not refactor or reformat adjacent code. Remove only the orphans your own change created. Note unrelated dead code, do not delete it. |
| Explicit cleanup / audit / refactor | **Aggressive.** Delete dead code, remove backwards-compat shims, split oversized files, fix anti-patterns across the touched area. This is the invoked job. |

The rule: never scope-creep during a feature. Clean aggressively only when cleanup is the
task the user asked for.

### 2.4 Fixed versus configurable

Some of the bar is fixed and non-negotiable across every project. Some of it is a per-project
choice, because reasonable teams differ. Polaris ships defaults but asks at setup.

| Fixed everywhere | Configurable per project |
|---|---|
| Simplicity first, root-cause not symptom, no workarounds | Dead code: delete on sight, flag, or keep |
| Self-explanatory naming, WHY-only comments | Backward compatibility: none (greenfield) or maintain |
| The prose bar (anti-slop writing) | Architecture and structure conventions |
| Security and validation at boundaries | Naming standards |
| Think before coding, verify after | PR and commit standards |

The configurable choices are captured in a project config that every layer reads (master plan
§2.6). This is what stops Polaris from being dogmatic: the same engine enforces a different
profile per project.

### 2.5 Personalization at setup

When Polaris is configured for a new project it interviews the user and writes a project
config. It asks:

- Dead code: delete on sight, flag for review, or keep.
- Backward compatibility: none (zero users, change freely) or maintain.
- Architecture and structure: describe it in words, point at a GitHub repo to mirror, point at
  a local project to mirror, or let Polaris decide.
- Naming standards: Polaris defaults, your own rules, or inferred from the reference project.
- PR and commit standards: your conventions or Polaris defaults.

Plus a **one-step (auto) mode**: the user lets Polaris decide everything from sensible defaults
and whatever it can infer from the existing code, with minimal questions. When the user points
at a GitHub or local reference, Polaris reads that project, infers its structure and naming,
and writes those into the config so its own output mirrors them.

### 2.6 The project config

A per-project, committed config (for example `.polaris/config.json`) holds every configurable
choice from §2.4 and §2.5. The gate, the hooks, and every agent read it and adjust behavior:
if backward compatibility is "maintain", the gate stops flagging compat shims; if dead code is
"keep", orphans are not errors; if a reference project defines the structure, agents mirror it.
The config is produced by the setup interview and can be re-run any time.

### 2.7 Think before coding, verify after

- Surface assumptions before implementing. If two interpretations exist, present both. If a
  simpler path exists, say so. If something is unclear, stop and ask. (Karpathy 1.)
- Turn every task into a verifiable goal with an explicit success check, then loop until the
  check passes. "Add validation" becomes "write tests for invalid input, then make them pass."
  (Karpathy 4.) This is the seed of the orchestration flow's verify-until-green loops.

---

## 3. The six subsystems

Polaris is not one project. It is six, built in order. Each is independently useful the day
it ships.

| # | Subsystem | What it is | Depends on | Status |
|---|---|---|---|---|
| **A** | Quality foundation | One canonical standard + a callable gate + opt-in hooks. The bedrock everything references. | none | **In design.** Spec: `docs/specs/2026-07-03-slice-a-quality-foundation.md` |
| **B** | Agent fleet | Specialized agents (UI, UX, frontend-logic, backend, general writer, tester/breaker, verifier, shipper, devops), each wiring the right host skills. | A | Planned |
| **C** | Handoff + audit docs | Handoff-doc creator (feature + audit variants), strict audit agent, enforced doc organization. | A | Planned |
| **D** | Orchestration flow | The full idea-to-merged-PR loop. A thin orchestrator that chains A, B, C. | A, B, C | Planned |
| **E** | Persistent memory + retrieval | Cross-session memory with pruning, RAG, external connectors, startup catch-up. | independent infra | Deferred (scoped in §7) |
| **F** | Prompt enhancing | Toggleable prompt enhancement. | none | Backlog (small) |

Build order: **A, then C, then B, then D.** E and F slot in independently.

### 3.1 The architectural rule that shapes everything

D is not a monolithic script. A, B, and C are built as composable primitives (agents,
skills, commands). D is a thin orchestrator command that chains them. Each primitive is
useful on its own, the flow is just the primitives wired together, and a fragile stage gets
fixed in isolation without touching the loop. A single twelve-stage "do everything" script is
the version that breaks constantly and cannot be debugged. We do not build that.

---

## 4. Subsystem A: quality foundation

Full detail in `docs/specs/2026-07-03-slice-a-quality-foundation.md`. Summary:

One canonical standard, one engine that enforces it, three ways to apply it.

- **Layer 1, the standard (single source).** `rules/core.md` (language-agnostic engineering
  principles + the docs protocol), `rules/writing.md` (the prose standard), `rules/stacks/`
  (thin Polaris overlays only where Polaris overrides a generic skill), and `patterns.json`
  (machine-readable banned words and forbidden tokens that feed the deterministic checks and
  the hooks).
- **Layer 2, the callable gate** (`skills/quality-gate/`). Detects the stacks in a changeset,
  loads the relevant host skills plus fresh docs plus Polaris overlays, then runs two passes:
  a mechanical pass (fast, from `patterns.json`) and a judgment pass (the model reads the diff
  against the standard). Outputs pass/fail plus findings with `file:line` and the fix. Modes:
  `--check` (default), `--fix`, `--scope code|writing|both`.
- **Layer 3, the hooks.** `guard-commit-pr` blocks a `git commit` or `gh pr create` whose
  message violates the writing standard. `guard-edit` surfaces violations after an edit
  (opt-in per project). `session-start` loads core + writing + only the detected stack
  overlays, keeping context lean.
- **The agents.** `code-cleanup` (merges the old `code-cleanup` and `slop-remover`, keeps all
  their triggers) and `audit-refactor` (evolved to be stack-aware). Both delegate the actual
  checking to the gate and read the one standard.
- **Setup and project config.** A setup interview (§2.5) writes `.polaris/config.json` with the
  per-project choices. The gate, hooks, and agents read it so enforcement matches the project's
  profile. The existing `init` command is the entry point.

### 4.1 Stack coverage comes from the skill library

Polaris does not hand-author stack knowledge. The host already has ~150 stack skills. The
stack layer is a resolution protocol:

1. **Detect** the stack and version from manifests (`package.json`, `pyproject.toml`,
   `go.mod`, `Cargo.toml`, and so on).
2. **Route to skills.** Map each detected technology to its host skill(s). If a mapped skill
   is not installed on the host, install it. If no skill exists, fall back to docs only.
3. **Fetch fresh docs (the docs protocol).** In order: `llms.txt` / `llms-full.txt` at the
   framework's doc domain, else version-specific official docs, else a targeted web search.
   This runs alongside the skill, not instead of it. Training data is never the source for
   version-specific APIs.
4. **Apply Polaris opinions.** `core.md` and `writing.md` always. Plus a `rules/stacks/<x>.md`
   overlay only where Polaris holds an opinion the generic skill lacks (for example TypeScript
   types-in-types-file and no-barrel-exports). Most stacks need no overlay.

"All stacks" is achieved by routing to everything already installed, not by writing a module
per language.

### 4.2 Companions, auto-installed

Polaris does not work alone. It leans on a set of companion plugins and skills, and it
installs all of them so the user never has to. The companions are:

- **superpowers** (brainstorming, planning, systematic debugging, verification, the process
  spine the flow builds on).
- **karpathy-skills** (the best-practice guidelines from master plan §2.3).
- **UI and design skills**: impeccable, huashu-design, ui-ux-pro-max, design-taste-frontend,
  frontend-design (the UI and UX agents wire these).
- **Stack skills**: the library the stack resolution protocol routes to (§4.1).

The set is declared in a companion manifest (`companions.json`) at the plugin root. Because
Claude Code has no true install-time hook for a plugin to install other plugins, the practical
mechanism is an idempotent ensure step: on first session start (and re-runnable from `init`),
Polaris checks which companions are present and installs the missing ones. It runs once per
project and is a no-op after that. This replaces the current session-start behavior, which only
warns when superpowers is absent.

---

## 5. Subsystem D: the orchestration flow

The full idea-to-merged-PR loop. Each stage is a call into an A/B/C primitive. Human approval
gates are explicit. No stage handwaves anything.

1. **Intake.** Accept a PRD or any docs, or run interview mode where Polaris generates the
   next question itself.
2. **Ambiguity loop.** Ask questions until every assumption is cleared and no ambiguity
   remains. Never proceed on a guess.
3. **Adversarial analysis.** Stress the idea from every persona who could touch the product:
   ideal customer, naive user, power user, attacker, and the rest. Exhaustive, not a sample.
4. **Spec.** Collate findings into a spec. Verify it with adversarial checks. Human approves.
5. **Plan.** Write the plan. Verify it with adversarial checks. Human approves. Loop until
   the plan is finalized and nothing is handwaved.
6. **Decompose.** Break the plan into isolated sub-plans that can run in parallel. Use git
   worktrees when parallel branches are needed.
7. **Implement with verification.** Per sub-plan: typecheck (for example `tsc`), build check,
   code-quality check, simplicity check, hand-patching check, anti-pattern check, architecture
   check. All from the quality gate.
8. **Review.** Reviewer agents for performance, security, code quality, simplicity, and
   maintainability.
9. **Verify and fix.** Verify every finding. Fix the legitimate ones, no exceptions. Rerun the
   review-and-verify loop until green.
10. **Acceptance.** Confirm the plan's acceptance criteria are met.
11. **QA adversarial.** Try to break the feature. Playwright or Claude-in-Chrome for web,
    best-effort through code elsewhere, curl for backend. Maniac-QA posture: the role is to
    find weakness and pressure-test, not to confirm it works.
12. **Root-cause bug fix.** Hand QA findings to the bug-fixer. Rework the logic properly. Fix
    the class of bug, not the one case. No hacky patches, no anti-patterns. Keep the code
    clean, maintainable, simple, scalable, performant.
13. **Verify fixes.** A verifier agent checks every fix, then QA runs again. Loop until QA
    passes clean.
14. **Commit and PR.** Commit and raise the PR to the project's standards (ask for the
    standards when Polaris is first set up in a project).
15. **Adversarial diff review.** Review the PR diff locally to find issues first. Fix via the
    bug-fixer. Loop until clean.
16. **CI.** Raise the PR, track CI, iterate until green.
17. **Report.** Final summary plus the PR link to merge.

---

## 6. Subsystem B: the agent fleet

Specialized agents, each wiring the relevant host skills for its job and installing missing
ones on the host. Karpathy best practices apply to every agent.

| Agent | Job | Example skills it wires |
|---|---|---|
| UI | Visual UI implementation | impeccable, huashu-design, ui-ux-pro-max, design-taste-frontend, frontend-design |
| UX | Flows, IA, interaction, copy | ux-design, accessibility-a11y |
| Frontend-logic | Non-UI frontend logic (state, data, hooks) | react-query, zustand, the framework skill |
| Backend | Services, APIs, data | the framework skill (fastapi, nestjs, go, spring, and so on), db skills |
| General writer | Code that fits no specialist | whatever the stack resolution returns |
| Tester / breaker | Adversarial QA, designed to break code | playwright, cypress, testing skills |
| Verifier | Confirms findings and fixes are real | the quality gate |
| Shipper | Commit, PR, release to standards | git-workflow, github-workflow |
| Devops | CI, infra, deploy | docker, kubernetes, terraform, ci-cd |

Every agent applies the quality gate before declaring done.

---

## 7. Subsystem C: handoff and audit docs

- **Handoff-doc creator**, two variants: feature handoff and audit handoff.
- **Strict audit agent**, modeled on the prod-readiness audit handoff style (see the user's
  `sage/PROD_READINESS_AUDIT_HANDOFF.md` as the quality reference).
- **Enforced doc organization.** All docs live under one directory, with set naming and a set
  architecture. No stray docs scattered across the repo.

---

## 8. Subsystem E: persistent memory and retrieval (deferred)

Scoped now, built later. The pain it solves: not having to re-explain context every morning
or in every new thread.

- Every session writes to a persistent memory store, with pruning so it does not grow
  unbounded.
- Retrieval on demand via RAG across everything.
- Connectors to external systems (Jira, Slack, Gmail, and others) to pull current tasks and
  context.
- A session-start choice: begin in Polaris hook mode or normal Claude mode. In hook mode,
  Polaris pulls context from everywhere and lays out what you were last working on, what else
  is open, and what it recommends doing next based on all of it.

This is genuine infrastructure (a store, embeddings, connectors, a hook), not markdown skills.
It gets its own spec when its turn comes.

---

## 9. Subsystem F: prompt enhancing (backlog)

Toggleable prompt enhancement. Small and standalone. Slots in whenever convenient.

---

## 10. Decisions locked so far

| Decision | Choice |
|---|---|
| First slice | A, the quality foundation |
| Enforcement model | Three layers: canonical standard, callable gate, opt-in hooks |
| Stack coverage | Resolution protocol over the host skill library, not hand-written modules |
| Docs freshness | llms.txt, then version docs, then search, alongside the skill |
| Quality-agent surface | Merge cleanup and slop-remover, keep audit-refactor separate |
| Flow architecture | Composable primitives plus a thin orchestrator, never a monolith |
| Philosophy inputs | Polaris quality bar + anti-slop writing + Karpathy best practices (mode-dependent) |
| Personalization | Setup interview writes a per-project config; fixed bar plus configurable knobs; one-step auto mode; can mirror a reference repo |
| Companions | Auto-installed via a manifest and an idempotent ensure step on first run (superpowers, karpathy, UI skills, stack skills) |
| Version control | Work stays on `main` for this project; no feature branches |

---

## 11. Open questions

- Exact `patterns.json` schema and how per-stack tokens are namespaced.
- Whether `guard-edit` blocks or only surfaces once it has proven itself in real use.
- The full memory architecture (subsystem E), deferred until its slice.
