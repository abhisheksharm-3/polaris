---
description: Run the full Polaris cycle on a task, from idea to a reviewed, tested, shipped change
argument-hint: "<task, PRD, or idea>"
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch
---

# Polaris orchestration cycle

Take the task in `$ARGUMENTS` from idea to a reviewed, tested, CI-green change. Run the phases
below, dispatching the fleet agent named for each phase and using the primitive named for it.
Scale the path to the task: a one-line fix skips discovery and architecture and runs a short path;
a real feature runs the whole thing. Read `.polaris/config.json` first and honor it.

## How to run each phase

- **Single delegated work** goes to a subagent (the `Task` tool with the named agent type).
- **Fan-out and verify-until-green loops** (review across dimensions, QA across cases) run as a
  dynamic workflow.
- **Genuinely adversarial phases** may run as an agent team when that experimental mode is enabled;
  otherwise use a workflow.
- Write every artifact to `.polaris/` per the doc-organization rule.

## The phases

### Phase 0 — Intake and discovery
Dispatch `product` to intake the PRD or run the interview, clearing every assumption. When the task
warrants it, dispatch `researcher` for feasibility and prior art. Do not proceed on a guess.

### Phase 1 — Spec
Dispatch `product` to write the spec with explicit acceptance criteria to `.polaris/specs/`.
**Stop. Present the spec and get the human's approval before continuing.**

### Phase 2 — Architecture and design
For a feature, dispatch in parallel: `architect` (structure and ADRs), `api-designer` (contracts),
`data-modeler` (schema and migrations), `security-architect` (threat model), and `ux` (flows and
copy). Collect the design docs. **Stop. Present the design and get approval.**

### Phase 3 — Plan
Use the writing-plans skill to turn the approved spec and design into an implementation plan, then
verify it adversarially (does any step handwave, is anything unproven). **Stop. Present the plan and
get approval. Loop until finalized.**

### Phase 4 — Implement
Decompose the plan into isolated sub-plans that can run in parallel; use git worktrees when they
touch overlapping files. Route each to its specialist: `ui`, `frontend-logic`, `backend`,
`integrations`, `infra`, or `data-engineer`. Each runs the quality gate before it reports done.

### Phase 5 — Review
Run a dynamic workflow: `reviewer` across the dimensions (correctness, security, performance,
maintainability, simplicity, accessibility), then `verifier` to confirm each finding is real. Fix
the confirmed ones (via `bug-fixer` or the relevant implementer). Loop until a clean pass, capped
at 3 rounds; on non-convergence, stop and escalate with the remaining findings and state.

### Phase 6 — QA
Dispatch `tester` for adversarial QA (drive the real feature: a browser for web, curl for backend),
plus `e2e` and `perf` as the task warrants. Hand every break to `bug-fixer` for a root-cause fix,
then `verifier` confirms, then QA runs again. Loop until QA passes clean, capped at 3 rounds; on
non-convergence, stop and escalate. Confirm the spec's acceptance criteria are met.

### Phase 7 — Docs
Dispatch `tech-writer` to update API docs, README, changelog, and migration notes to match the
shipped code.

### Phase 8 — Ship
Dispatch `shipper`: commit to the project's standards, review the diff adversarially first (fix via
`bug-fixer`, loop until clean), open the PR with release notes, then track CI and iterate until
green, capped at 3 rounds; on non-convergence, stop and escalate.

### Phase 9 — Operate (as applicable)
Dispatch `devops` to deploy and `sre` to ensure logging, metrics, tracing, and alerts exist for the
change.

### Phase 10 — Report
Write a final report to `.polaris/reports/`: what was built, what was found and fixed, what is
accepted with rationale, the residual risk, the PR link, and the spend (from telemetry when
enabled).

## Rules

- Approval gates at spec, design, and plan are hard stops. Never pass a gate without the human.
- No verify loop runs unbounded. Every one caps at 3 rounds, then stops and escalates with state.
- Nothing outward-facing (push, PR, deploy, connector write) happens without confirmation unless
  the config authorizes it.
- Every emitted line, code and prose, passes the quality gate and the writing standard.
- Evidence before claims: run the command, show the output; never assert passing or done unproven.
