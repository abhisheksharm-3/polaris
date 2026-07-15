# Slice D+G: Orchestration Cycle and Standalone Modes — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §5 (D), §6.1 (G), §10.0 (primitive choice). Depends on A, C, B.

D chains the fleet into the idea-to-shipped lifecycle. G exposes task-scoped agents you invoke on
their own. They share the fleet, the gate, the guardrails, and the doc layout.

## Problem

The fleet exists but nothing orchestrates it. A feature still means driving each agent by hand.
And many jobs are not features at all (research what to build, onboard a developer), yet there is
no one-shot entry point for them.

## Goal

A `/flow` command that runs the full cycle with explicit human-approval gates and failure caps,
and a set of standalone-mode commands that each run one self-contained job.

### Success criteria

- `/flow <task>` runs the phased cycle from master plan §5, dispatching the right fleet agent per
  phase, using the right primitive (subagent, workflow, agent team) per §10.0, pausing at the spec,
  design, and plan gates, and scaling the path to task size.
- Every verify-until-green loop has a hard iteration cap; on non-convergence the cycle stops,
  reports state, and escalates. No infinite loops.
- `/research`, `/onboard`, and `/explain` each run their job end to end and write any artifact to
  `.polaris/` per the doc-organization rule.
- Every command passes the writing standard.

## Architecture

### D: the `/flow` orchestrator

`commands/flow.md`. Input: a task (feature request, PRD, or idea) as `$ARGUMENTS`. It runs the
phases and decides the path from task size and `.polaris/config.json`: a one-line fix skips
discovery and architecture; a real feature runs the whole thing.

Phase to agent and primitive:

| Phase | Agent(s) | Primitive | Gate |
|---|---|---|---|
| 0 Intake and discovery | product, researcher | subagent | — |
| 1 Spec | product | subagent | **human approves the spec** |
| 2 Architecture and design | architect, api-designer, data-modeler, security-architect, ux | subagents (parallel) | **human approves the design** |
| 3 Plan | writing-plans skill | subagent, adversarial verify | **human approves the plan** |
| 4 Implement | ui, frontend-logic, backend, integrations, infra, data-engineer | subagents; worktrees when parallel | inline gate per sub-plan |
| 5 Review | reviewer (per dimension), verifier | dynamic workflow (fan-out + verify) | loop until green (capped) |
| 6 QA | tester, e2e, perf, bug-fixer, verifier | workflow; agent team for adversarial analysis | loop until clean (capped); acceptance criteria met |
| 7 Docs | tech-writer | subagent | — |
| 8 Ship | shipper | subagent | adversarial diff review; CI to green (capped) |
| 9 Operate (as applicable) | devops, sre | subagent | — |
| 10 Report | (the orchestrator) | — | summary + PR link |

Rules baked in:

- **Approval gates** at spec, design, and plan are explicit stops. Because a workflow takes no
  mid-run input, each gated phase completes, then `/flow` pauses for the human before the next.
- **Failure and loop caps:** every verify-until-green loop caps at a fixed number of rounds
  (default 3). On non-convergence, stop, report the remaining failures and the state, escalate to
  the human. Never loop forever, never silently give up.
- **Primitive choice** per §10.0: subagents for single tasks, dynamic workflows for fan-out and
  verify loops, agent teams for genuinely adversarial phases (behind the experimental flag; fall
  back to a workflow when off).
- **Artifacts** go to `.polaris/` (spec, design, plan, reports).
- **Cost:** the run reports spend at the end (from the telemetry, when enabled).

### G: standalone modes

Each is a `commands/*.md` that runs one job, invoking the relevant fleet agents, worktree-isolated
when it writes.

- `commands/research.md` — project research and feature ideation. Reads the code and data,
  researches the web, pulls from connectors, and proposes what to build next with reasoning. Uses
  the researcher agent. Writes `.polaris/reports/<date>-research-<topic>-report.md`.
- `commands/onboard.md` — dev onboarding. Reads the repo, history, architecture, and docs and
  writes an onboarding doc: what the project is, how it is structured, how to run it, where to
  start. Writes `.polaris/reports/<date>-onboarding-report.md`.
- `commands/explain.md` — codebase explainer. Answers "how does X work here" grounded in the actual
  code. Read-only; no artifact unless asked.

## Testing and validation

- Commands are orchestration prompts; validate structurally: each parses, has valid frontmatter,
  references only agents that exist in `agents/`, and passes `check-patterns.sh prose`.
- A small check asserts every agent named in `flow.md` exists as an agent file (no dangling
  references).

## Out of scope

- F (prompt enhancing), H (dynamic synthesis), E (memory) — later milestones.
- Building new workflow-runtime features; `/flow` uses the existing Workflow tool and subagents.
