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

Polaris is becoming an all-in-one operating system for a project inside Claude Code. It runs
the full software development lifecycle, from a rough idea through research, design, build,
review, QA, docs, ship, and operate, and it also runs the work around the code: product and
feature research, marketing and growth, brainstorming, and operations. Anything a person does
for a project, Polaris aims to do well, through three surfaces:

- **The feature cycle** (subsystem D): the orchestrated idea-to-shipped lifecycle.
- **Standalone modes** (§6.1): task-scoped agents you invoke on their own, such as researching
  what to build next or onboarding a new developer.
- **Dynamic agents** (§6.2): agents synthesized on the fly from the skill registries for a task
  no predefined agent covers.

It holds one quality bar across all of it: the code it produces is simple, performant, secure,
self-explanatory, and low in complexity, and every line of prose it emits (comments, commits,
PR text, docs, and marketing copy) reads like a careful human wrote it, not an LLM.

The north star: you should be able to hand Polaris a PRD, a vague idea, or a standing question
like "what should we build next", and get back work done to a standard you did not have to
police by hand.

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

## 3. The subsystems

Polaris is not one project. It is a set of subsystems, built in order. Each is independently
useful the day it ships.

| # | Subsystem | What it is | Depends on | Status |
|---|---|---|---|---|
| **A** | Quality foundation | One canonical standard + a callable gate + opt-in hooks. The bedrock everything references. | none | **Built** v0.3.0 |
| **B** | Agent fleet | A specialized agent for every role across every domain (§3.3): engineering, product, research, marketing, docs, and ops. Each wires the right host skills. | A | **Built** v0.6.0 (27 agents) |
| **C** | Handoff + audit docs | Handoff-doc creator (feature + audit variants), strict audit agent, enforced doc organization. | A | **Built** v0.4.0 |
| **D** | Orchestration cycle | The full idea-to-shipped lifecycle. A thin orchestrator that chains A, B, C. | A, B, C | **Built** v0.7.0 |
| **E** | Persistent memory + retrieval | Cross-session memory with pruning, connectors, startup catch-up, and the auto-maintained work tracker (§8.4). | independent infra | **Built** v0.8.0 (tracker) + v0.10.0 (memory); embeddings RAG deferred |
| **F** | Prompt enhancing | Toggleable prompt enhancement (can wire the EARS prompt-optimizer skill). | none | **Built** v0.9.0 |
| **G** | Standalone modes | Task-scoped agents invoked on their own, outside the cycle (research, onboarding, and more). Detailed in §6.1. | A, B | **Built** v0.7.0 |
| **H** | Dynamic agent synthesis | Compose an agent on the fly from the skill registries for a task no predefined agent covers. Detailed in §6.2. | A, B | **Built** v0.11.0 |
| **I** | Guardrails | A `PostToolUse` regex denylist that flags injection markers in untrusted input and tells the agent to treat the content as data. Detailed in §4.3. | A | **Built** v0.5.0 (denylist; model-classifier upgrade open) |
| **J** | Model routing | Selector agent + minimum-model-per-task policy. Detailed in §6.3. | A, B | **Built** v0.5.0 |

All subsystems shipped in the **1.0.0** release (2026-07-15). Historical build order was A, C, J+I,
B, D+G, work tracker, F, E, H. Remaining refinements: embeddings-backed RAG for memory (needs a
backend) and connector activation (needs claude.ai auth). See `CHANGELOG.md`.

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

### 3.3 Domains: beyond engineering

Polaris covers a project's whole surface, not only its code. The domains, each staffed by its
own agents (§6) and available as standalone modes (§6.1):

- **Build** — the SDLC in §3.2.
- **Product and research** — feature ideation, user and market research, competitive analysis,
  feasibility, roadmap input.
- **Marketing and growth** — content, SEO, social, email, ads, landing pages, branding, launch
  campaigns.
- **Docs and comms** — technical docs, changelogs, announcements, internal writeups.
- **Operations** — devops, observability, incident response, dependency and tech-debt upkeep.

Every domain inherits the same quality bar, the same anti-slop writing standard, and the same
gate. Marketing copy passes the writing standard exactly as commit messages do.

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
3. **The discovery registries** — several indexes Polaris queries to find a skill it does not
   have, including non-code roles like product, research, marketing, and docs. This is how
   "install the missing skill" works in general:
   - `awesomeskills.dev` (`llms.txt`) — 1000+ skills across coding, design, content, marketing,
     PM, research, writing, video.
   - `crossaitools.com` (`llms.txt`) — 21k+ skills, 12k+ MCP servers, 2.5k+ marketplaces, daily
     updated from GitHub. Install via `/plugin marketplace add <owner/repo>`.
   - `skillsmp.com` — 2M+ skills, with a **REST API and an MCP server** (`skillsmp.com/mcp`).
     This is the programmatic backend for on-the-fly discovery and dynamic agent synthesis
     (§6.2), since Polaris can query it directly rather than scraping a page.
   - `skillsdirectory.com` — security-tested skills with **A–F security grades**. Polaris uses
     these grades as a trust filter: prefer verified, high-grade skills, and never auto-install
     an ungraded or low-grade skill without surfacing it first.

Notable individual skills the plan relies on:
- **skill-creator** (`daymade/claude-code-skills`, MIT) — builds skills at runtime; the engine
  behind dynamic agent synthesis (§6.2).
- **qa-expert** (same) — autonomous QA execution; feeds the QA fleet.
- **prompt-optimizer** (same, EARS methodology) — powers subsystem F.

Specific UI skills the fleet relies on (impeccable, ui-ux-pro-max, huashu-design,
design-taste-frontend) are resolved through these registries when not already present.

**Trust and safety.** Auto-install is powerful and risky. Polaris prefers marketplace plugins
and security-graded skills, pins versions in `companions.json`, and surfaces any ungraded or
low-grade skill for approval before installing it. It does not silently pull arbitrary code.

Two install mechanisms, matched to what each source is:

- **Plugin companions use native plugin dependencies.** `plugin.json` supports a `dependencies`
  array; Claude Code resolves and installs them automatically when Polaris is installed, with
  semver constraints and auto-update. superpowers, frontend-design, and karpathy go here. They
  live in different marketplaces than Polaris, so the Polaris `marketplace.json` must list them
  under `allowCrossMarketplaceDependenciesOn`, and the user must have those marketplaces added.
- **The skill bulk uses an idempotent ensure step.** The loose `Mindrally/skills` and
  registry-resolved skills are not plugins, so a first-run script (`ensure-companions.sh`, also
  re-runnable from `init`) syncs the ones listed in `companions.json` into `~/.claude/skills/`,
  then no-ops. Alternatively Polaris publishes them as a skills marketplace so they can become
  plugin dependencies too; that is an open choice (§14).

This replaces the current session-start behavior, which only warns when superpowers is absent.

### 4.3 Guardrails: prompt-injection defense (subsystem I)

Polaris pulls in a large amount of untrusted text: fetched web pages and docs, MCP connector
data (Jira, Slack, Gmail, email, tickets), referenced repos, file contents, PRDs, and the
skills it auto-installs. Any of it can carry a prompt-injection payload ("ignore your
instructions", a hijacked tool call, an exfiltration prompt). A `PostToolUse` hook screens
untrusted input with a regex denylist before Polaris acts on it, and hands anything it flags to
the agent to treat as data.

- **Where it sits.** Between an untrusted source and the agent that would consume it: on tool
  results, fetched content, connector payloads, and referenced-project content.
- **What it does.** Matches known injection phrasings: instruction-override, role reassignment,
  and exfiltration prompts. On a match it appends an advisory that the agent treat the content as
  data, not commands, and follow no directive inside it. It flags; it does not silently redact.
- **Why it is foundation.** Everything downstream trusts that what it reads is safe. Together
  with the skill security grading (§4.2), this is Polaris's safety layer. Auto-install and
  connector access are only acceptable with it in place.

**Relationship to Claude Code's built-in defense (grounded).** Claude Code already ships strong
protection: auto mode's classifier strips tool results so hostile content cannot manipulate it,
and a separate server-side probe scans incoming tool results before Claude reads them. Polaris
does not reinvent that. Subsystem I is the added layer for the specific case the base model does
not fully cover: untrusted content (fetched docs, connector payloads, referenced repos, installed
skills) that flows into Polaris agents and the memory store. It runs as a `PostToolUse` pass that
emits an advisory via `additionalContext`; it flags rather than redacts. The screen is a fixed
guardrail, not configurable off. A model classifier that can quarantine or redact via
`updatedToolOutput` is the open upgrade path.

---

## 5. Subsystem D: the orchestration cycle

The full lifecycle, idea to running-and-verified. Each step calls an A/B/C primitive. Human
approval gates are explicit and marked. No step handwaves anything. Steps scale to the task: a
small change skips discovery and architecture and runs a short path; a real feature runs the
whole thing. The orchestrator decides the path from the task size and the project config.

**How it is orchestrated (grounded in §10.0).** Fan-out phases (review across dimensions, QA
across cases, the verify-until-green loops) run as dynamic workflows, which hold the loop in a
script and can run adversarial verification across hundreds of agents. Genuinely adversarial
phases where perspectives must challenge each other (the persona analysis, competing-hypothesis
debugging) can run as an agent team. Single delegated steps are subagents. Because a workflow
takes no mid-run input, each human-approval-gated phase (spec, design, plan) is its own workflow;
the orchestrator command chains them and pauses for sign-off between them. Deploy verification
and CI-reactive steps can run as routines.

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

Audit, refactor, dependency upgrades, and tech-debt burn-down. Run on demand, or unattended as
**routines**: a nightly audit, a weekly dependency and docs-drift check, a GitHub-triggered
review on every PR, an API-triggered incident triage from monitoring. Routines run in the cloud
on a schedule, an HTTP call, or a repository event, so this track keeps working with the laptop
closed.

---

## 6. Subsystem B: the agent fleet

A specialized agent for every SDLC role, grouped by phase. Each wires the relevant host skills
for its job and installs missing ones (§4.2). Karpathy best practices apply to every agent, and
every agent applies the quality gate before declaring done. This is the full roster; it is built
incrementally, and simple tasks use only a few of these.

### 6.0 The agent contract

So 25+ agents stay consistent instead of drifting, every fleet agent follows one template,
grounded in the verified plugin-agent frontmatter (`model`, `effort`, `maxTurns`, `tools`,
`disallowedTools`, `skills`, `memory`, `background`, `isolation`):

- **Model and effort** come from the routing policy (J): the agent's default tier is set in
  frontmatter and matches its task class.
- **Least privilege.** `tools` and `disallowedTools` grant only what the role needs. A reviewer
  reads and runs checks; it does not write.
- **Skills wired, not duplicated.** The `skills` field lists the host skills the role uses.
  Knowledge lives in the skill; the agent body holds only the role's judgment.
- **Isolation.** An agent that writes files in parallel sets `isolation: worktree`.
- **A fixed body shape.** Every agent body states its role, then: load `.polaris/config.json`
  and the standard, resolve stack skills and fresh docs (§4.1), do the work to the fixed bar,
  run the quality gate before declaring done, and return output in the role's defined shape.
- **What plugin agents cannot do.** `hooks`, `mcpServers`, and `permissionMode` are ignored for
  plugin-shipped agents, so agents rely on session-level config for those, and the auto-mode
  classifier evaluates every subagent regardless of any requested mode.

The contract is written once as a spec and a template file; each agent fills in role, skills,
tools, model, and output shape.

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

### Marketing and growth

| Agent | Job | Example skills |
|---|---|---|
| Content / SEO | Articles, landing copy, SEO, GEO | seo-best-practices, content and writing skills |
| Social / campaigns | Social posts, ad creative, launch campaigns | ckm-banner-design, ckm-slides, social skills |
| Brand | Voice, identity, visual system | ckm-brand, brandkit, ckm-design |
| Growth / analytics | Experiments, funnels, product analytics | analytics-data-analysis, Mixpanel/PostHog MCP |

### Strategy

| Agent | Job | Example skills |
|---|---|---|
| Brainstorm facilitator | Structured ideation and option framing | superpowers:brainstorming |
| Roadmap / prioritization | Sequencing, tradeoffs, what-next | deep-research, data-analyst |

All marketing and strategy output passes the anti-slop writing standard (§2.2).

### 6.1 Standalone modes (subsystem G)

Not everything is a feature. Many jobs are a single self-contained task with its own goal and
its own output. A standalone mode is a task-scoped agent you invoke directly, run in isolation
(its own context, its own worktree when it touches files), and get back an artifact or report.
It uses the same fleet, skills, gate, guardrails, and MCP connectors as the cycle, but it does
not run the cycle.

Seed modes:

| Mode | What it does |
|---|---|
| Project researcher / feature ideation | Reads the code and data, researches the web, pulls from MCP connectors (Jira, analytics, Slack), and proposes what to build next with reasoning and evidence. |
| Dev onboarding | Reads the repo, history, architecture, and docs and onboards a new developer: what the project is, how it is structured, how to run it, where to start. |
| Codebase explainer | Answers "how does X work here" grounded in the actual code. |
| Competitive / market analysis | Researches competitors and the market, returns a positioned summary. |
| Tech-debt triage | Surfaces and ranks debt with a suggested burn-down order. |
| Campaign runner | Plans and drafts a marketing campaign end to end. |
| Incident / RCA | Triage and root-cause analysis of a production incident. |

The list is open. New modes are cheap: a mode is a goal plus the agents and skills it wires.

### 6.2 Dynamic agent synthesis (subsystem H)

For a task no predefined agent covers, Polaris builds one on the fly:

1. Classify the task and the capabilities it needs.
2. Search the discovery registries (the `skillsmp.com` API and MCP are the programmatic path)
   for matching skills.
3. Filter by security grade (§4.2 trust and safety). Surface anything ungraded for approval.
4. Compose an ephemeral agent, a system prompt plus the wired skills, using `skill-creator`.
5. Run it under the same quality gate and guardrails as any other agent.
6. Persist it as a named fleet agent only if it proves useful repeatedly.

This is designed now so the architecture supports it, and may not ship in the first cut. It is
what lets Polaris handle "anything and everything" without a predefined agent for every
possibility.

### 6.3 Model routing (subsystem J)

Every agent and cycle step runs on a model chosen by a model-selector, not left to default. The
selector's sole job is to map a task to the right model from a fixed policy. The policy sets the
model floor per task class: harder or higher-stakes work must not run on a weaker model.

| Task class | Model | Rationale |
|---|---|---|
| Breaking / adversarial QA, interview and intake, planning, spec, architecture, threat model, review, RCA, adversarial verification | Opus | Deep reasoning and high cost of error. The floor is Opus. |
| Code writing (implementation) | Sonnet | Sonnet writes code, exclusively. |
| Very simple one-off tasks (trivial mechanical edits, formatting, single-fact lookups) | Haiku | Only genuinely trivial work. When in doubt, do not use Haiku. |

Rules:

- The floor is a minimum, not a cap. The selector may go higher when a task is unusually hard,
  never lower than the policy.
- Code writing is Sonnet. QA, planning, interviewing, and anything adversarial is Opus. Haiku is
  reserved for the trivial and is the exception, not a cost-saving default.
- The policy lives in the standard so a project can extend it, and the selector reads it. Agents
  and the cycle call the selector rather than hardcoding a model.

---

## 7. Subsystem C: handoff and audit docs

- **Handoff-doc creator**, two variants: feature handoff and audit handoff.
- **Strict audit agent**, modeled on the prod-readiness audit handoff style (see the user's
  `sage/PROD_READINESS_AUDIT_HANDOFF.md` as the quality reference).
- **Enforced doc organization.** All docs live under one directory, with set naming and a set
  architecture. No stray docs scattered across the repo.

---

## 8. Subsystem E: persistent memory and retrieval (deferred)

Scoped now, built later. The pain it solves: not having to re-explain context every morning or
in every new thread.

### 8.1 What it holds

Three kinds of memory, each with a different lifetime:

- **Working memory** — what the current and recent sessions were doing: the active task, open
  threads, decisions in flight. Short-lived, pruned aggressively.
- **Project memory** — durable facts about the project: architecture, conventions, decisions,
  the config, recurring gotchas. Long-lived, curated.
- **External context** — pulled live from connectors, not stored: Jira tickets, Slack threads,
  email, calendar, analytics. Fetched on demand, never the source of truth.

The existing file-based memory (the `memory/` directory this session already writes to) is the
seed for working and project memory. Subsystem E grows it into a retrievable store.

### 8.2 How it works

- **Write.** Sessions write structured memory entries as they go, the same shape the current
  memory system uses, with a type and a one-line description.
- **Prune.** A background pass ages out stale working memory and dedupes, so the store stays
  small and relevant. Project memory is kept unless contradicted.
- **Retrieve.** On demand via RAG: embed the entries, retrieve the relevant ones for the task
  at hand rather than loading everything. This is why it is real infrastructure (a store plus
  embeddings), not markdown.
- **Store (backing).** The default is local and private: a SQLite database plus a vector index
  in `.polaris/`, with embeddings from a local model or an embedding API. Local keeps it working
  offline and in headless runs, and keeps project data on the machine. An MCP-backed vector store
  is an option for teams that want shared memory. Always-loaded facts still live in `CLAUDE.md`
  and the agent `memory` field; the store is for what is too large to keep in context.
- **Connect.** MCP connectors (Jira, Slack, Gmail, Calendar, analytics) pull external context.
  All connector data passes the injection classifier (§4.3) before use.

### 8.3 Startup catch-up

A session-start choice: begin in Polaris hook mode or normal Claude mode. In hook mode, Polaris
pulls from memory and the connectors and lays out what you were last working on, what else is
open, and what it recommends doing next based on all of it. This is the "turn it on in the
morning and it already knows" experience.

### 8.4 The work tracker (auto-maintained, cross-session)

The flagship use of the memory system, and the one that answers a real daily pain: you run many
threads at once (improving UI/UX, diagnosing a bug, changing backend logic, prototyping a
feature, building a new flow), and you lose track of what you were doing, sometimes until it is
too late. Polaris keeps the list for you. You never maintain it.

**Where it lives.** The memory store is the source of truth, with an optional one-way mirror to
an external task tool. Memory is canonical because the tracker must hold rich, code-linked,
cross-session state that a flat checkbox app cannot: which files a thread touches, the current
hypothesis, what was tried last, what is next. It also needs no auth, so it works in headless
and routine runs. There is no Google Tasks connector; the mirror targets, when you want the list
on your phone, are Notion, Linear, or Jira over MCP. The mirror carries a summary; memory keeps
the depth.

**What it tracks: work streams, not flat todos.** Each stream holds:

- an id and a title,
- a domain (ui, ux, backend, bug, prototype, feature, infra, docs),
- a status (active, paused, blocked, done),
- a one-line summary and the current state or last action,
- the single next step,
- related files and links,
- the last session and time it was touched.

Many streams run in parallel, which matches how you actually work.

**How it stays current without you (grounded in real hooks).** Claude maintains it as a side
effect of the session:

- `UserPromptSubmit` classifies the prompt into an existing stream or opens a new one.
- `PostToolUse` on `Edit`/`Write` attaches the touched files to the active stream.
- `Stop` records progress and the next step at the end of each turn.
- `SessionEnd` snapshots every open thread.
- `SessionStart` surfaces the active streams, what each was doing, and the next step, flags stale
  ones, and recommends where to resume. This is the §8.3 catch-up, driven by the tracker.
- The native in-session todo (`TaskCreate`/`TodoWrite`) is ephemeral; the tracker persists it at
  `SessionEnd` and rehydrates it at `SessionStart`, so per-session todos survive across sessions.

**Lifecycle.** Streams age. Stale ones are flagged ("the backend refactor has not moved in five
days"), completed ones are archived, and nothing is silently dropped. Pruning keeps the set
lean without losing history.

**The guarantee.** At any session start you see every open thread and the one next step for each,
so nothing is lost and tasks get finished.

**Early MVP.** A file-based version, extending the existing `memory/` directory, can ship before
the full embeddings store: streams as structured files, maintained by the hooks above. Semantic
retrieval and the connector mirror arrive with full subsystem E.

It gets its own spec when its turn comes. The dependency that makes it safe to build, the
injection classifier (I), is part of the foundation.

---

## 9. Subsystem F: prompt enhancing (backlog)

Toggleable prompt enhancement, in two steps so it never touches a prompt that was already clear:

1. **Judge.** A cheap first pass decides whether enhancement is even needed. A clear, specific
   prompt is left alone. Only a vague, ambiguous, or underspecified prompt moves on.
2. **Enhance.** When needed, produce an enriched version using all available context (the
   project config, memory, the repo, connector data). It can wire the EARS `prompt-optimizer`
   skill (§4.2).

Mechanism, grounded in the real hook API: a `UserPromptSubmit` hook cannot rewrite the prompt in
place, only block it or inject `additionalContext`. So the judge runs in that hook and, when
enhancement helps, injects the enriched framing as context Claude sees alongside the original,
rather than silently replacing it. A heavier rewrite is offered as an explicit command the user
can invoke. Toggleable per the user's preference. Small and standalone.

---

## 10. How it maps to Claude Code

The vision is ambitious, so it is anchored in primitives Claude Code actually provides, verified
against the current docs (2026): a plugin ships skills, agents, hooks, MCP servers, LSP servers,
monitors, output styles, and commands. Orchestration uses subagents, agent teams, dynamic
workflows, and routines.

| Subsystem | Built from |
|---|---|
| A quality foundation | `rules/` (prose + `patterns.json`); `skills/quality-gate`; optional **LSP servers** (typescript, pyright, rust-analyzer) feeding the gate real diagnostics; an **output style** (`output-styles/`, `force-for-plugin`) enforcing the writing standard at the system-prompt level; hooks: `SessionStart`, `PreToolUse` (guard commit/PR, can `deny` or rewrite via `updatedInput`), `PostToolUse` (guard edits), `SubagentStop`/`Stop` (block finish until the gate passes); `commands/gate`; `agents/code-cleanup` + `audit-refactor`. Companions via native plugin `dependencies`. |
| B agent fleet | one `agents/*.md` per role. Plugin-agent frontmatter (verified): `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation: worktree`. Not `hooks`/`mcpServers`/`permissionMode` (ignored for plugin agents). Agents wire host skills via the `skills` field. |
| C handoff + audit docs | agents + `commands/` (handoff, audit), writing to the `.polaris/` workspace |
| D cycle | an orchestrator command that chains **dynamic workflows** (fan-out audits and verify-until-green loops), **subagents** (single delegated tasks), and **agent teams** (adversarial phases). Each human-approval-gated phase is its own workflow, because a workflow takes no mid-run input. |
| E memory | file memory (seed) + an embeddings store over MCP + the `SessionStart` hook + the agent `memory` field |
| F prompt enhancing | a `UserPromptSubmit` hook that judges and injects `additionalContext` (it cannot rewrite the prompt) + a command for explicit rewrites |
| G standalone modes | `commands/*` invoking a scoped agent with `isolation: worktree`; some exposed as **routines** (scheduled research, on-demand onboarding) |
| H dynamic synthesis | `skill-creator` + the `skillsmp` registry (REST/MCP) + an ephemeral subagent (a written `agents/*.md` or CLI `--agents` JSON) |
| I guardrails | a classifier skill run via `PostToolUse` (`updatedToolOutput` to quarantine or redact) and `PreToolUse` `additionalContext`, on untrusted tool results and fetched content |
| J model routing | native per-agent `model` and `effort` frontmatter; workflow stages route via `agent(..., { model, effort })`; the policy (§6.3) maps task class to tier |

### 10.0 Choosing the right orchestration primitive

The docs draw a clear line between the four; Polaris picks per phase rather than forcing one.

| Primitive | Who holds the plan | Use it for |
|---|---|---|
| Subagent | Claude, turn by turn | A focused delegated task where only the result matters. The default. |
| Agent team | A lead over peer sessions | Peers that must talk and challenge each other: adversarial analysis, competing-hypothesis debugging, multi-lens review. Higher token cost; experimental (env flag). |
| Dynamic workflow | A script the runtime runs | Dozens to hundreds of agents, deterministic, resumable, with adversarial-verify built in: audits, migrations, verify-until-green. |
| Routine | A schedule or trigger | Unattended cloud runs on a cadence, an API call, or a GitHub event: maintenance, deploy verification, morning catch-up, alert triage. |

### 10.1 Command surface

What the user types. The set grows, but the spine:

| Command | Does |
|---|---|
| `/polaris` (or `init`) | Setup interview, write `.polaris/config.json`, ensure companions |
| `/gate` | Run the quality gate on the changeset |
| `/audit` | Whole-codebase audit (subsystem C) |
| `/flow` | Run the full orchestration cycle on a task |
| `/research` | Project research / feature ideation mode (G) |
| `/onboard` | Dev onboarding mode (G) |
| `/explain` | Codebase explainer mode (G) |
| `/handoff` | Generate a handoff doc (C) |
| `/ship` | Commit, PR, CI-to-green (phase 8) |
| `/schedule` | Register a routine for scheduled maintenance, morning catch-up, or triggered runs |

Polaris commands that orchestrate at scale (`/flow`, `/audit`, `/research`) are implemented as
saved dynamic workflows, which the runtime exposes as `/` commands and which accept `args`. This
is how the cycle stays deterministic and resumable rather than turn-by-turn improvisation.

---

## 11. Cross-cutting operations

Concerns that apply to every subsystem, not just one.

- **Run workspace and artifacts.** Everything Polaris produces lands in a single `.polaris/`
  tree per project: `config.json`, and `runs/`, `specs/`, `plans/`, `reports/`, `handoffs/`.
  This is the enforced doc organization from subsystem C, applied to Polaris's own output. No
  stray files.
- **Permissions and safety (grounded in the real model).** Claude Code enforces permissions
  itself, not the model, with allow/ask/deny rules evaluated deny-first and a precedence of
  managed over CLI over local over project over user. Polaris uses this rather than inventing a
  policy layer:
  - The setup writes a starting rule set into project settings: read-only and safe commands
    allowed, outward-facing or destructive actions (`git push`, `gh pr create`, deploys, secret
    access) set to ask or gated by the config.
  - For autonomous cycle runs, Polaris recommends **auto mode**, whose classifier blocks
    escalations, unrecognized infrastructure, and hostile-content-driven actions, and whose
    server-side probe scans tool results before Claude reads them. This is the first safety
    layer; subsystem I adds a `PostToolUse` pass for the specific case of untrusted content
    flowing into agents (§4.3).
  - **Protected paths** (`.git`, `.claude`, shell and package configs) are never auto-approved
    outside bypass mode, so Polaris cannot corrupt repo or tool state by accident.
  - Boundaries you state in chat ("don't push yet") are honored by the classifier. Teams can
    lock Polaris's policy through managed settings.
  - Nothing outward-facing happens without confirmation unless the config authorizes it.
- **Rollback and checkpointing.** Claude Code checkpoints every file edit made through its edit
  tools and exposes `/rewind`, persisting across sessions. Polaris relies on this: agents edit
  through file tools (checkpointed and undoable), and use git for permanent history. The known
  gap is that bash-driven file changes (`rm`, `mv`) are not checkpointed, so Polaris avoids
  destructive bash, prefers file tools, and establishes a clean git commit point before any
  large auto-change so there is always a place to roll back to.
- **Failure handling and loop caps.** Every verify-until-green loop has a maximum iteration
  count. On non-convergence Polaris stops, reports the remaining failures and the state, and
  escalates to a human rather than looping forever. Retries are bounded. No silent give-up and
  no infinite loop. Workflow runs also carry hard caps (16 concurrent agents, 1000 per run) as
  a runaway backstop.
- **Budgets and cost (grounded, and extractable live).** Cost is not just shown in `/usage`, it
  is readable programmatically, so Polaris runs a real spend meter:
  - **OpenTelemetry** (`CLAUDE_CODE_ENABLE_TELEMETRY=1`) emits `claude_code.cost.usage` (USD) and
    `claude_code.token.usage`, attributed by `model`, `query_source` (main vs subagent),
    `agent.name`, `skill.name`, `plugin.name`, and `session.id`, plus a `claude_code.api_request`
    event carrying `cost_usd` per request. Polaris reads this stream to attribute spend per agent
    and per phase in real time.
  - **Agent SDK and workflow** results expose `total_cost_usd` and a per-model `modelUsage`
    breakdown per query, so agents run that way report their own cost directly.
  - A Polaris **statusline** surfaces running cost and budget remaining, since the statusline
    script receives cost on stdin.
  - **Enforcement.** There is still no built-in "stop at $X per run" in the CLI, so Polaris sets
    a per-run ceiling and watches the telemetry stream against it: it pauses and asks as a run
    approaches the ceiling, and states actual spend in the final report. Model routing (J), effort
    tiers, context-shrinking hooks, subagent delegation, and workflow caps keep the baseline low.
    For a hard cap, Console workspace spend limits or a gateway sit underneath.
  - All of the above are client-side estimates; authoritative dollars come from the Console usage
    and cost API.
- **Concurrency and isolation.** Parallel sub-plans and standalone modes run in git worktrees
  so they do not collide, under a concurrency cap.
- **Observability.** Three sources. Workflow runs are inspectable live through the `/workflows`
  view (per-phase agent count, token total, elapsed time, drill into any agent). **OpenTelemetry**
  metrics and events give per-agent, per-skill, per-session cost and token counts that Polaris
  reads for the spend meter and the run log. For live external signals (CI status, error logs),
  Polaris ships plugin **monitors** (`monitors/monitors.json`) that watch a command's output and
  surface lines to Claude as notifications. Polaris writes its own run history to `.polaris/runs/`:
  which agents ran, on which model, at what cost, with what findings and outcomes.
- **Privacy.** Connector data is sensitive. It is used in-session and not persisted unless the
  user opts in, and it always passes the injection classifier first.

---

## 12. Milestones

Each milestone is independently useful the day it ships.

| Milestone | Contents |
|---|---|
| **M1** | Slice A: the standard, the gate, the hooks, the config, companions. The foundation. |
| **M2** | Subsystem C: handoff-doc creator and the strict audit agent, run-workspace layout. |
| **M3** | Subsystem B core agents + J model routing + I guardrails. |
| **M4** | Subsystem D cycle (the orchestrator) + G standalone modes. |
| **M5** | F prompt enhancing + H dynamic agent synthesis. |
| **M5.5** | Work-tracker MVP (§8.4): file-based work streams maintained by hooks. Small, high daily value, can land as soon as the hooks exist. |
| **M6** | E persistent memory and connectors (embeddings retrieval, the tracker's mirror, startup catch-up). |

---

## 13. Decisions locked so far

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
| Scope | All-in-one project OS: the whole SDLC plus product, research, marketing, docs, ops |
| Surfaces | The feature cycle, standalone modes (G), and dynamic agents (H) |
| Companions | Native plugin `dependencies` for marketplace plugins (cross-marketplace allowlisted) + an idempotent ensure step for the loose skill bulk |
| Skill sources | Marketplace plugins + `Mindrally/skills` (Apache-2.0) for the stack bulk + discovery registries (`awesomeskills.dev`, `crossaitools.com`, `skillsmp.com` API/MCP, `skillsdirectory.com` with A–F security grades) |
| Orchestration | Per-phase choice: subagents (default), agent teams (adversarial debate), dynamic workflows (fan-out + verify loops), routines (scheduled/triggered). D chains workflows with sign-off between them. |
| Safety | Lean on Claude Code's auto-mode classifier + server-side tool-result probe; subsystem I adds a `PostToolUse` pass for untrusted content into agents/memory; security-graded skill installs |
| Permissions | Use Claude Code's allow/ask/deny rules (deny-first, managed-wins); setup writes a starting rule set; protected paths never auto-approved |
| Rollback | Rely on native checkpointing (`/rewind`) + git; agents edit via file tools, avoid destructive bash, set a clean commit point before big auto-changes |
| Cost control | Live spend meter from OpenTelemetry cost/token metrics (per agent/skill/session) + SDK `total_cost_usd` + a statusline; per-run ceiling watched against the stream, pause-and-ask near it; baseline held by model routing + effort + caps; hard cap via Console/gateway |
| Memory storage | Local SQLite + vector index in `.polaris/` by default (private, offline); MCP store optional for teams |
| Agent contract | One template for all fleet agents (§6.0): model/effort from policy, least-privilege tools, skills wired, fixed body shape, gate before done |
| Writing enforcement | Anti-slop as an output style (`force-for-plugin`) at the system-prompt level, plus the gate and the commit/PR hook |
| Model routing | Native per-agent `model` + `effort` frontmatter (J); Opus floor for planning/QA/interview/review/adversarial, Sonnet for code, Haiku only for trivial |
| Minimalism | The ponytail companion + its laziness ladder in `core.md`; code writers build the least code that works; auto-injects into subagents |
| Task routing | `rules/routing.md` classifies each task to the agent, command, ponytail intensity, and model tier |
| Work tracking | Auto-maintained work streams in the memory store (source of truth), maintained by hooks; optional one-way mirror to Notion/Linear/Jira. No manual upkeep. |
| Version control | Work stays on `main` for this project; no feature branches |

---

## 14. Open questions

- Exact `patterns.json` schema and how per-stack tokens are namespaced.
- Whether `guard-edit` blocks or only surfaces once it has proven itself in real use.
- Whether to publish the skill bulk as a Polaris skills marketplace (so it becomes a plugin
  dependency and installs natively) or keep the `ensure-companions.sh` sync. Leaning marketplace.
- Agent teams are experimental and gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. Decide
  whether D's adversarial phases require them or fall back to workflows when the flag is off.
- Whether subsystem I's `PostToolUse` classifier runs on every untrusted result or only on
  higher-risk sources, to balance coverage against latency and tokens.
- Connector authentication in headless or routine runs, where interactive auth is absent.
- Which embedding model backs the local memory store, and its size and refresh cost.
- The full memory architecture (subsystem E), deferred until its slice.
- Whether to ship the file-based work-tracker MVP (§8.4) early, ahead of full subsystem E, since
  it solves a daily pain and needs only hooks plus the existing `memory/` directory.
- Auto-classification accuracy for the work tracker: how reliably a prompt or edit is attached to
  the right stream, and how the user corrects a misfile cheaply.
- Which mirror target to default to (Notion, Linear, or Jira) and whether the mirror is per
  project or per user.
