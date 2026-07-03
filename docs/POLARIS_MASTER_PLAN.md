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

Polaris is becoming an opinionated, end-to-end engineering system for Claude Code. It runs the
full software development lifecycle, from a rough idea through research, design, build, review,
QA, docs, ship, and operate, with a specialized agent for every role. It holds one quality bar
across every step: the code it produces is simple, performant, secure, self-explanatory, and
low in complexity, and every line of prose it emits (comments, commit messages, PR text, docs)
reads like a careful human wrote it, not an LLM.

The north star: you should be able to hand Polaris a PRD or a vague idea, answer its questions,
approve its spec and plan, and get back a reviewed, tested, CI-green, documented change built to
a standard you did not have to police by hand.

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
| **B** | Agent fleet | A specialized agent for every SDLC role: product, research, architecture, API and data design, security, UX, UI, implementation, review, QA, docs, ship, devops, ops, and maintenance. Each wires the right host skills. | A | Planned |
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

### 3.2 Scope: the whole SDLC, not just code-to-PR

Polaris covers the full software development lifecycle, and it has an agent for every role a
real team fills, not only the coding ones. The phases:

1. Intake and discovery (requirements, research, feasibility)
2. Specification (adversarial analysis, spec, acceptance criteria)
3. Architecture and design (system, API, data, threat model, UX, UI)
4. Planning (breakdown, estimation, risk, parallel decomposition)
5. Implementation (frontend, backend, data, infra, integrations)
6. Review (correctness, security, performance, maintainability, simplicity, accessibility)
7. QA and testing (adversarial, e2e, exploratory, regression, load, pentest, a11y audit)
8. Documentation (API docs, README, changelog, ADRs, user docs)
9. Ship (commit, PR, release notes, CI to green)
10. Release and operate (deploy, observability, prod verification, incident response, RCA)
11. Maintenance (audit, refactor, dependency upgrades, tech-debt)

Subsystem D (§5) is the cycle that runs these phases. Subsystem B (§6) is the fleet of role
agents that staff them. The fleet is the full roster; it is built incrementally, not all at
once.

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

Polaris does not hand-author stack knowledge. The skill ecosystem already covers it (§4.2).
The stack layer is a resolution protocol:

1. **Detect** the stack and version from manifests (`package.json`, `pyproject.toml`,
   `go.mod`, `Cargo.toml`, and so on).
2. **Route to skills.** Map each detected technology to its host skill(s). If a mapped skill
   is missing, install it from the skill sources in §4.2 (Mindrally for stacks, the
   awesomeskills registry for anything else). If no skill exists anywhere, fall back to docs.
3. **Fetch fresh docs (the docs protocol).** In order: `llms.txt` / `llms-full.txt` at the
   framework's doc domain, else version-specific official docs, else a targeted web search.
   This runs alongside the skill, not instead of it. Training data is never the source for
   version-specific APIs.
4. **Apply Polaris opinions.** `core.md` and `writing.md` always. Plus a `rules/stacks/<x>.md`
   overlay only where Polaris holds an opinion the generic skill lacks (for example TypeScript
   types-in-types-file and no-barrel-exports). Most stacks need no overlay.

"All stacks" is achieved by routing to everything already installed, not by writing a module
per language.

### 4.2 Companions and skill sources

Polaris does not work alone. It installs everything it leans on so the user never has to. There
are three sources, each with its own install path:

1. **Marketplace plugins** (installed with a plugin-install command):
   - **superpowers** — brainstorming, planning, systematic debugging, verification. The
     process spine the flow builds on.
   - **frontend-design** — Anthropic's design skill (the UI agent wires it).
   - **karpathy-skills** — the best-practice guidelines from §2.3
     (`github.com/multica-ai/andrej-karpathy-skills`).
2. **The stack and skill bulk** — `github.com/Mindrally/skills`, Apache-2.0, 240+ skills
   converted from Cursor Rules (React, Vue, Django, FastAPI, Go, Rust, Docker, Kubernetes, and
   the rest). Installed by syncing folders into `~/.claude/skills/`. This is the real upstream
   for the stack library. It carries a permissive license, so redistribution and syncing are
   allowed; per-skill attribution is preserved.
3. **The discovery registry** — `awesomeskills.dev` (its `llms.txt`), a searchable index of
   1000+ skills across coding, design, content, marketing, PM, research, writing, and video.
   When Polaris needs a skill it does not have, including non-code SDLC roles like product,
   research, or docs, it looks the capability up here and installs from the listed source. This
   is how "install the missing skill" works in general.

Specific UI skills the fleet relies on (impeccable, ui-ux-pro-max, huashu-design,
design-taste-frontend) are resolved through the registry when not already present.

The full set is declared in a manifest (`companions.json`) at the plugin root. Because Claude
Code has no true install-time hook for a plugin to install other plugins, the mechanism is an
idempotent ensure step: on first session start, and re-runnable from `init`, Polaris checks
what is present and installs the rest, then no-ops on later runs. This replaces the current
session-start behavior, which only warns when superpowers is absent.

---

## 5. Subsystem D: the orchestration cycle

The full lifecycle, idea to running-and-verified. Each step calls an A/B/C primitive. Human
approval gates are explicit and marked. No step handwaves anything. Steps scale to the task: a
small change skips discovery and architecture and runs a short path; a real feature runs the
whole thing. The orchestrator decides the path from the task size and the project config.

### Phase 0 — Intake and discovery

1. **Intake.** Accept a PRD or any docs, or run interview mode where Polaris generates the next
   question itself.
2. **Ambiguity loop.** Ask questions until every assumption is cleared and no ambiguity remains.
   Never proceed on a guess.
3. **Discovery and feasibility.** When the task warrants it, research users, market,
   competitors, and technical feasibility (the deep-research skill). Surface risks early.

### Phase 1 — Specification

4. **Adversarial analysis.** Stress the idea from every persona who could touch the product:
   ideal customer, naive user, power user, attacker, and the rest. Exhaustive, not a sample.
5. **Spec.** Collate into a spec with explicit acceptance criteria. Verify it adversarially.
   **Human approves.**

### Phase 2 — Architecture and design

6. **System architecture.** Design the structure and record the decisions and tradeoffs (ADRs).
7. **API and data design.** Contracts and data model, versioned and reviewed.
8. **Threat model.** Security by design: attack surface, trust boundaries, mitigations.
9. **UX and UI design.** Flows, information architecture, interaction, copy, accessibility, and
   the visual direction. Verify the design adversarially. **Human approves.**

### Phase 3 — Planning

10. **Plan, estimate, risk.** Write the plan with estimates and risks. Verify it adversarially.
    **Human approves.** Loop until finalized and nothing is handwaved.
11. **Decompose.** Break the plan into isolated sub-plans that can run in parallel. Use git
    worktrees when parallel branches are needed.

### Phase 4 — Implementation

12. **Build.** Route each sub-plan to its specialist agents (UI, frontend-logic, backend, data,
    infra, integrations). Test-driven where it fits.
13. **Inline verification.** Per sub-plan: typecheck, build, lint, quality gate, simplicity
    check, hand-patch check, anti-pattern check, architecture check. All from the gate.

### Phase 5 — Review

14. **Multi-dimension review.** Reviewer agents for correctness, security, performance,
    maintainability, simplicity, and accessibility.
15. **Verify and fix.** Verify every finding. Fix the legitimate ones, no exceptions. Rerun the
    review-and-verify loop until green.

### Phase 6 — QA and testing

16. **Adversarial QA.** Try to break the feature. Playwright or Claude-in-Chrome for web,
    best-effort through code elsewhere, curl for backend. Add exploratory, regression, load and
    performance, security pentest, and accessibility audit as the task warrants. The posture is
    to find weakness and pressure-test, not to confirm it works.
17. **Root-cause bug fix.** Hand findings to the bug-fixer. Rework the logic properly. Fix the
    class of bug, not the one case. No hacky patches, no anti-patterns. Keep the code clean,
    maintainable, simple, scalable, performant.
18. **Verify fixes.** A verifier agent checks every fix, then QA runs again. Loop until QA
    passes clean.
19. **Acceptance.** Confirm the spec's acceptance criteria are met.

### Phase 7 — Documentation

20. **Docs.** Update or write API docs, README, changelog, ADRs, user docs, and migration notes.
    All pass the writing standard.

### Phase 8 — Ship

21. **Commit and PR.** Commit and raise the PR to the project's standards (from the project
    config; ask if not set), with release notes.
22. **Adversarial diff review.** Review the PR diff locally to find issues first. Fix via the
    bug-fixer. Loop until clean.
23. **CI.** Raise the PR, track CI, iterate until green.

### Phase 9 — Release and operate (as applicable)

24. **Deploy.** Through the project's CI/CD.
25. **Observability.** Ensure logging, metrics, tracing, and alerts exist for the change.
26. **Verify in production and respond.** Confirm behavior after release. On an incident, run
    incident response and a root-cause analysis, then feed fixes back through the cycle.

### Phase 10 — Report

27. **Report.** Final summary, the PR link to merge, and any follow-ups or tech-debt logged.

### Maintenance track (ongoing, outside the per-feature cycle)

Audit, refactor, dependency upgrades, and tech-debt burn-down, run on demand or on a schedule.

---

## 6. Subsystem B: the agent fleet

A specialized agent for every SDLC role, grouped by phase. Each wires the relevant host skills
for its job and installs missing ones (§4.2). Karpathy best practices apply to every agent, and
every agent applies the quality gate before declaring done. This is the full roster; it is built
incrementally, and simple tasks use only a few of these.

### Discovery and product

| Agent | Job | Example skills |
|---|---|---|
| Product / BA | Requirements, PRD, acceptance criteria | deep-research, technical-writing |
| Researcher | User, market, competitive, feasibility research | deep-research, data-analyst |

### Architecture and design

| Agent | Job | Example skills |
|---|---|---|
| Architect | System design, ADRs, tradeoffs | clean-architecture, microservices |
| API / contract designer | API surface and contracts | graphql, api-development, grpc |
| Data modeler / DBA | Schema, migrations, query design | postgresql, prisma, mongodb, sql |
| Security architect | Threat model, trust boundaries, mitigations | security-best-practices, jwt/oauth |
| UX | Flows, IA, interaction, copy, accessibility | ux-design, accessibility-a11y |
| UI | Visual UI implementation | impeccable, ui-ux-pro-max, huashu-design, design-taste-frontend, frontend-design |

### Implementation

| Agent | Job | Example skills |
|---|---|---|
| Frontend-logic | Non-UI frontend logic (state, data, hooks) | react-query, zustand, the framework skill |
| Backend | Services and business logic | the framework skill (fastapi, nestjs, go, spring...) |
| Integrations | Third-party APIs, webhooks, payments | stripe, the relevant provider skills |
| Infra / IaC | Provisioning and infra as code | terraform, aws/gcp/azure, kubernetes |
| Data / ML | Pipelines and models, when applicable | pandas, pytorch, langchain |
| General writer | Code that fits no specialist | whatever the stack resolution returns |

### Review and verification

| Agent | Job | Example skills |
|---|---|---|
| Reviewer (per dimension) | Correctness, security, performance, maintainability, simplicity, accessibility | the gate + the relevant stack skills |
| Verifier | Confirms findings and fixes are real | the quality gate |

### QA and testing

| Agent | Job | Example skills |
|---|---|---|
| Tester / breaker | Adversarial, maniac QA to break the feature | playwright, cypress, testing |
| E2E | End-to-end flows in a real browser | playwright, claude-in-chrome |
| Performance / load | Throughput, latency, load tests | performance-optimization |
| Security / pentest | Active security testing of the change | python-cybersecurity, security-best-practices |
| Accessibility audit | WCAG conformance | accessibility-a11y |
| Bug-fixer | Root-cause fixes, class of bug not the case | systematic-debugging + stack skills |

### Documentation

| Agent | Job | Example skills |
|---|---|---|
| Technical writer | API docs, README, changelog, ADRs, user docs | technical-writing |

### Ship and operate

| Agent | Job | Example skills |
|---|---|---|
| Shipper / release | Commit, PR, release notes, changelog, versioning | git-workflow, github-workflow |
| DevOps / CI | Pipelines, build, deploy | docker, ci-cd, kubernetes |
| SRE / observability | Logging, metrics, tracing, alerts | observability, monitoring, logging |
| Incident response / RCA | Triage and root-cause analysis of incidents | systematic-debugging |

### Maintenance

| Agent | Job | Example skills |
|---|---|---|
| Audit-refactor | Whole-codebase audit and refactor (from Slice A) | the gate + stack skills |
| Dependency / upgrade | Dependency updates and migrations | the relevant stack and migration skills |

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
| Lifecycle scope | The whole SDLC, every role, not just code-to-PR |
| Companions | Auto-installed via a manifest and an idempotent ensure step on first run |
| Skill sources | Marketplace plugins (superpowers, frontend-design, karpathy) + `Mindrally/skills` (Apache-2.0) for the stack bulk + `awesomeskills.dev` registry for on-demand discovery |
| Version control | Work stays on `main` for this project; no feature branches |

---

## 11. Open questions

- Exact `patterns.json` schema and how per-stack tokens are namespaced.
- Whether `guard-edit` blocks or only surfaces once it has proven itself in real use.
- The full memory architecture (subsystem E), deferred until its slice.
