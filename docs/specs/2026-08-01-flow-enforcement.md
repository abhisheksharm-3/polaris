# Flow Enforcement: the run ledger, sequence gates, and the phase engine — Design Spec

Date: 2026-08-01. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md`. Supersedes the orchestration described in `commands/flow.md`.

Polaris has 29 commands and one orchestration cycle. The cycle is markdown, so whether it runs is
the model's choice. This spec moves the sequence into state and hooks, and the fan-out into
workflow scripts.

## Problem

Polaris enforces at the leaf and nowhere else.

- `guard-edit` blocks an inline comment. `guard-commit-pr` blocks a banned word. `guard-review`
  blocks a reviewer that skipped the over-engineering axis. `stop-capture` blocks a session that
  skipped capture. Four real gates, all on a single action.
- The sequence has none. `commands/flow.md` describes 11 phases and calls the spec, design, and
  plan approvals "hard stops". Every one of those words is advice to a model that may abridge it.
- Nothing records which phase a task is in, that a phase finished, or what it produced. So a
  session that starts at phase 4 looks identical to one that passed phases 0 through 3.
- The verify loops cap at 3 rounds by asking the model to count.
- `/route` maps a situation to a command and stops, so stitching a multi-command path is manual
  every time.

The missing primitive is run state. Without it no gate can know what to allow.

## Goal

A durable per-task run ledger, deterministic hooks that refuse out-of-order phases, workflow
scripts that hold the fan-out and the loops, and a Stop-hook engine that advances the chain and
pauses at the human gates.

### Success criteria

- `/polaris:build` on a task whose spec is not approved is denied by a hook, not discouraged by a
  paragraph.
- A run's ledger records, per phase, the artifact path, its hash, and the check output that passed
  it. A phase cannot report done without them.
- Review and QA exit on convergence (two consecutive rounds finding nothing new), with a round
  ceiling as a runaway guard rather than the exit condition.
- Every finding is confirmed by three verifiers with different lenses, surviving on a majority.
- `/polaris:go <task>` classifies the task, seeds the phase list, and the chain runs to the next
  human gate without the user naming another command.
- A single command clears a run, and no hook blocks twice for the same phase transition.

## Architecture

### Layer 1: the run ledger

`.polaris/runs/<slug>/state.json`, owned by one script, `scripts/run-state.sh`, matching how
`sweep-window.sh` and `okr-pace.sh` already own their state.

```
{
  "slug": "referral-codes",
  "shape": "feature",
  "phases": ["spec", "design", "build", "ship"],
  "current": "design",
  "record": {
    "spec": {
      "status": "approved",
      "artifact": ".polaris/specs/2026-08-01-referral-codes-spec.md",
      "sha256": "...",
      "evidence": "gate: pass (0 findings)",
      "approvedAt": "2026-08-01T09:14:22Z"
    }
  }
}
```

Subcommands: `get`, `seed`, `record`, `approve`, `assert <phase>`, `clear`. `assert` is the one
the hooks call; it exits non-zero with a reason on stderr when the named phase may not start.

Status alone would let a phase claim done, so the record carries evidence. `artifact` must exist,
`sha256` must match it, and `evidence` must hold the output of the check that passed it. This is
what makes Rule 12 enforceable rather than aspirational.

The human-readable run log at `.polaris/runs/<date>-flow-<slug>.md` stays as it is. The ledger is
the machine state; the log is the narrative.

### Layer 2: sequence enforcement

Four hooks, all deterministic, none consulting a model.

| Hook | Matcher | Refuses |
|---|---|---|
| `UserPromptExpansion` | `polaris:design\|polaris:build\|polaris:ship` | A phase whose predecessor is not approved in the ledger |
| `PreToolUse` | `Task` | Dispatching an implementation agent while the ledger's current phase is `spec` or `design` |
| `Stop` | — | Ending a session with an open phase, once per transition |
| `TaskCompleted` | — | Ticking a phase task off before its evidence exists |

`UserPromptExpansion` receives `command_name`, `expanded_prompt`, and `cwd`, and blocks with a
top-level `{"decision": "block", "reason": "..."}`. That is enough to resolve the project directory,
read the ledger, and deny by name. It is the primary gate.

`TaskCompleted` is the one piece whose input schema the hooks reference does not publish. It is
additive: the evidence check also runs in the Stop hook, so the design does not depend on
`TaskCompleted` landing. If testing shows it carries no usable task identity, it is dropped.

### Layer 3: execution

Six scripts under `workflows/` at the plugin root, namespaced `/polaris:<name>` on install.

- `spec` — intake and ambiguity loop, research where warranted, spec with acceptance criteria
- `design` — three independent architectures, parallel judges, synthesis from the winner, then the
  specialists (`api-designer`, `data-modeler`, `security-architect`, `ux`) against the chosen shape
- `build` — implement, review fan-out, verifier panel, QA loop
- `ship` — gate, adversarial diff review, PR, CI to green
- `gate` and `review` — the verify-until-clean fan-outs, callable on their own

Three quality patterns are the reason these are scripts and not prose:

**Loop until dry.** Review and QA keep running finders until two consecutive rounds surface nothing
new, deduping against every finding seen so far rather than against the confirmed set. A fixed cap
of 3 stops whether the work converged or not. A ceiling stays as a runaway guard.

**Diverse verification.** Each finding goes to three verifiers with different lenses (correctness,
security, does-it-reproduce), each prompted to refute, surviving on a majority. Three identical
verifiers catch less than three different ones.

**Judge panel on architecture.** `flow.md` phase 2 fans out five specialists who each own a slice,
so no agent ever proposes a competing whole. Drafting three architectures and scoring them
produces a chosen shape; the specialists then work against it.

Every `agent()` call passes `opts.agentType` naming a fleet agent. Without it the runtime spawns a
generic subagent, and the tool restrictions added to the fleet in 1.9.0 do not apply. Model and
effort come from `rules/model-routing.md` via `opts.model` and `opts.effort`, which turns a policy
nothing enforced into per-stage code.

### Layer 4: the phase engine

The Stop hook advances the chain. After a phase workflow finishes and the turn ends, it reads the
ledger:

- phase done, awaiting approval → block, instructing the model to present the artifact and stop
- phase approved, next phase exists → block, instructing it to run the next phase command
- run complete, or no run open → silent

The pauses land between workflows, in conversation. That resolves the runtime constraint that a
workflow cannot take input mid-run: sign-off never needs to happen inside one.

It blocks at most once per phase transition, using the atomic-mkdir marker `stop-capture` already
proves out, and `/polaris:pause` clears the run. A gate with no exit gets switched off within a
week, and a gate that is off enforces nothing.

`/polaris:go <task>` is the single entry point. Its first agent classifies the task shape and
returns the phase list; the script seeds the ledger and runs phase one. A one-line fix seeds
`["build", "ship"]`; a feature seeds all four. From there the Stop hook drives it.

Two supporting pieces: a `statusLine` reading `polaris: <slug> · design 2/4 · awaiting approval`,
so run state is visible rather than inferred, and `disable-model-invocation: true` on the phase
commands, so the model cannot fire a phase out of order on its own.

## Not in scope

- **Agent teams.** A second orchestrator buys nothing the Stop-hook engine does not already do.
- **Checkpointing.** Git covers revert, and Polaris work happens on main.
- **`PostToolBatch`.** No gate needs to stop the agentic loop mid-turn.
- **Converting the sweep family.** `/sweep`, `/journal`, `/track`, and `/catchup` are already
  script-backed and have no ordering problem to solve.

## Risks

- **`SubagentStart` may not fire for workflow-spawned agents.** `inject-standard` is how the
  Polaris standard reaches every agent. If the hook does not fire inside a workflow, those agents
  work without it and quality drops silently. This must be tested before any phase moves out of a
  `Task` dispatch. If it does not fire, each workflow prompt carries the standard explicitly.
- **Workflow subagents always run in `acceptEdits`,** regardless of session permission mode. File
  edits inside a phase are auto-approved. Acceptable for `build`; the reason `ship` keeps its
  outward-facing confirmations in the command layer rather than the script.
- **`TaskCreated` and `TaskCompleted` input schemas are undocumented.** Treated as additive above.
- **The installed plugin cache is stale relative to this repo.** None of the hook work is testable
  in-session without a plugin update, so Layer 2 needs a real update-and-test cycle.

## Test plan

- `scripts/run-state.sh` gets a shell fixture test: seed, record, approve, and an `assert` that
  fails on an unapproved predecessor and passes on an approved one.
- A fixture test that the ledger rejects a `record` whose artifact is missing or whose hash does
  not match.
- A hook test that `UserPromptExpansion` denies `polaris:build` against a ledger with an unapproved
  spec, and allows it against an approved one.
- A live test that a Stop-hook block fires once and not twice for the same transition.
- A live workflow run confirming whether `SubagentStart` fires for its agents.

## Build order

1. `scripts/run-state.sh` and its tests. Everything else reads it.
2. The `UserPromptExpansion` gate and the Stop engine, against hand-seeded ledgers.
3. `/polaris:build` as one workflow, run on a real task, measured against the current `/flow`.
4. The remaining five workflows.
5. `/polaris:go`, the classifier, and the statusLine.
