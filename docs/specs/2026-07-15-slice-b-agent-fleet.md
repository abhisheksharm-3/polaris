# Slice B: Agent Fleet — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §6 (fleet), §6.0 (contract). Depends on Slice A, J+I.

The full roster: a specialized agent for every role across every domain, each following one
contract so 25+ agents stay consistent instead of drifting.

## Problem

Polaris has four agents (code-cleanup, audit-refactor, feature-builder, prod-audit). The
orchestration cycle (M4) and the domains (build, product, research, marketing, docs, ops) need a
role agent for each phase. Without a shared contract they would drift.

## Goal

Author the full roster as `agents/*.md`, each following the agent contract, wiring the right host
skills, and carrying a model tier per the routing policy (J). This slice creates the agents; the
cycle that chains them is M4.

### Success criteria

- Every agent below exists as `agents/<name>.md` with valid plugin frontmatter (only `name`,
  `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`,
  `background`, `isolation`), a contract section, role duties, and an output shape.
- Every agent's prose passes the writing standard.
- Model tiers match the routing policy: Opus for planning, research, architecture, security,
  review, verification, and adversarial QA; Sonnet for implementation, test-writing, docs, and ship.

## The agent contract (every agent follows it)

```
---
name: <name>
description: |
  <one-line role> + 2 trigger examples
model: <opus|sonnet>
skills: <comma-separated host skills the role wires>
---

You are <role>.

## Contract
Follow the Polaris agent contract: load .polaris/config.json and the standard (core.md, writing.md,
the stack overlay), resolve the stack skills and fresh docs via the docs protocol, do the work to
the fixed bar, and run the quality gate before declaring done. Honor the config's dead-code and
backward-compat policy. Feature work is surgical; invoked cleanup is aggressive.

## Responsibilities
<the role's specific duties>

## Output
<what it returns: an artifact path, a report shape, or a changeset + gate result>
```

## The roster

Existing (keep): `code-cleanup` (sonnet), `audit-refactor` (opus), `feature-builder` (sonnet),
`prod-audit` (opus).

New agents:

| Agent | Role | Model | Skills |
|---|---|---|---|
| product | Requirements, PRD, acceptance criteria | opus | deep-research, technical-writing |
| researcher | User, market, competitive, feasibility research | opus | deep-research, data-analyst |
| architect | System design, ADRs, tradeoffs | opus | clean-architecture, microservices |
| api-designer | API surface and contracts | opus | graphql, api-development, grpc-development |
| data-modeler | Schema, migrations, query design | opus | postgresql-best-practices, prisma, mongodb-development, sql-best-practices |
| security-architect | Threat model, trust boundaries, mitigations | opus | security-best-practices, jwt-security, oauth-implementation |
| ux | Flows, information architecture, interaction, copy, accessibility | sonnet | ux-design, accessibility-a11y |
| ui | Visual UI implementation | sonnet | impeccable, ui-ux-pro-max, huashu-design, design-taste-frontend, frontend-design |
| frontend-logic | Non-UI frontend logic (state, data, hooks) | sonnet | react-query, zustand-state-management |
| backend | Services and business logic | sonnet | api-development, nodejs-development |
| integrations | Third-party APIs, webhooks, payments | sonnet | stripe |
| infra | Provisioning and infrastructure as code | sonnet | terraform, docker, kubernetes |
| data-engineer | Pipelines and models, when applicable | sonnet | pandas-best-practices, pytorch |
| reviewer | Multi-dimension code review | opus | security-best-practices, performance-optimization |
| verifier | Confirms findings and fixes are real | opus | (the quality gate) |
| tester | Adversarial, maniac QA to break the feature | opus | playwright, cypress, testing |
| e2e | End-to-end flows in a real browser | sonnet | playwright, playwright-cli |
| perf | Throughput, latency, load | sonnet | performance-optimization |
| bug-fixer | Root-cause fixes, class of bug not the case | sonnet | (systematic-debugging) |
| tech-writer | API docs, README, changelog, ADRs | sonnet | technical-writing |
| shipper | Commit, PR, release notes, changelog | sonnet | git-workflow, github-workflow |
| devops | Pipelines, build, deploy | sonnet | ci-cd-best-practices, docker |
| sre | Logging, metrics, tracing, alerts | sonnet | observability-guidelines, monitoring-guidelines |

The `reviewer` covers correctness, security, performance, maintainability, simplicity, and
accessibility as lenses in one agent (not one agent per lens), invoked per dimension by the caller.

## Testing and validation

- Agents are prompt files; validate structurally: every file parses, carries an allowed-only
  frontmatter set, has the four sections, and passes `check-patterns.sh prose`.
- A small validation script asserts each agent has `name`, `description`, `model`, and `skills` and
  that `model` is `opus` or `sonnet`.

## Out of scope

- The orchestration cycle that chains these (M4).
- Standalone modes (G) and dynamic synthesis (H).
- Skills that do not yet exist on the host resolve through the registry at run time; this slice does
  not author skills.
