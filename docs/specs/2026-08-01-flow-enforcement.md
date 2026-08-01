# Flows as Data: routing, the run ledger, and the phase engine — Design Spec

Date: 2026-08-01. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md`. Supersedes the orchestration described in `commands/flow.md`.

Polaris has 29 commands and one flow. The flow is markdown, so whether it runs is the model's
choice, and it only runs when a human types `/flow`. This spec makes a flow a row in a table, has
Polaris pick the row from what the user described, and enforces the row with hooks.

## Problem

**Enforcement stops at the leaf.** `guard-edit` blocks an inline comment, `guard-commit-pr` blocks
a banned word, `guard-review` blocks a reviewer that skipped the over-engineering axis, and
`stop-capture` blocks a session that skipped capture. Four real gates, each on a single action.
The sequence has none: `commands/flow.md` describes 11 phases and calls three approvals "hard
stops", and every one of those words is advice to a model that may abridge it.

**There is one flow, and it is the largest one.** A bug, an incident, a release, a security pass,
and a dependency upgrade each have a natural sequence, and Polaris has a command for most of the
steps. What it lacks is any record that the steps compose. So `/flow` is either overkill or the
work runs as a pile of hand-invoked commands with nothing checking the order.

**Every path starts with a typed command.** `/route` maps a situation to a command and then stops.
The day's work follows a Polaris path only when the user remembers a path exists and picks the
right one, which most days does not happen.

**Nothing knows where the work is.** No record of which phase a task is in, that a phase finished,
or what it produced. A session that starts at implementation looks identical to one that earned
its way there.

## Goal

Polaris picks the flow from what the user described, records it, runs it, and refuses to let it be
run out of order. The user describes work and approves at the gates.

### Success criteria

- A described task routes and runs with no command typed. "The referral code field accepts
  duplicates" runs the bug flow starting at a reproduction; "add a referrals page" runs the feature
  flow starting at a spec; "what does this hook do" runs nothing and stays a question.
- A task matching no named flow gets one composed from the 27 agents and 29 commands, announced
  before it runs, and enforced exactly as a named flow is. No task is handed back unrouted.
- Adding a flow is adding a row to `rules/flows.json`. No new script, no new command. A composed
  flow used more than twice becomes a row.
- Dispatching an implementation agent while the ledger says the phase is `spec` is denied by a
  hook, not discouraged by a paragraph.
- Each phase records the artifact, its hash, and the check output that passed it. A phase cannot
  report done without them.
- Review and QA exit on convergence, not on a round counter the model keeps.
- One command clears a run, and no hook blocks twice for the same phase transition.

## Architecture

Four pieces: a flow catalog (data), a run ledger (state), hooks (enforcement), and workflows
(execution for the phases that fan out).

### 1. Flows are data

`rules/flows.json`. Each flow is an ordered phase list, each phase names a tool Polaris already
has and whether it needs human approval before the next phase starts.

```
{
  "bug": {
    "match": "flow",
    "phases": [
      { "name": "reproduce", "run": "agent:bug-fixer", "evidence": "a failing case" },
      { "name": "rootcause", "run": "command:debug", "approve": true },
      { "name": "fix",       "run": "agent:bug-fixer" },
      { "name": "verify",    "run": "workflow:verify" },
      { "name": "ship",      "run": "workflow:ship" }
    ]
  }
}
```

`run` is one of `agent:<name>` from the fleet, `command:<name>` from `commands/`, or
`workflow:<name>` for the phases that fan out. A flow is not code, so a new one costs a table row.

The catalog, derived from the task classes already in `rules/routing.md`:

| Flow | Phases |
|---|---|
| `conversation` | none; the prompt is a question |
| `trivial` | edit, gate |
| `fix` | specialist, gate, ship |
| `bug` | reproduce, rootcause, fix, verify, ship |
| `feature` | spec, design, build, ship |
| `foggy` | recon, spec, design, build, ship |
| `spike` | spike, decide, then discard or hand to `feature` |
| `review` | review, verify |
| `audit` | audit, triage, fix, verify |
| `qa` | break, fix, verify |
| `cleanup` | cleanup, gate, ship |
| `security` | threat-model, find, fix, verify |
| `incident` | mitigate, rootcause, prevent, notes |
| `release` | gate, notes, release |
| `modernize` | survey, upgrade, qa, ship |
| `docs` | drift, write, gate |
| `research` | research |
| `context` | catchup |

Eighteen flows against today's one, and `feature` is the row that `commands/flow.md` describes.
Sixteen of them compose commands that already exist and ship today.

The catalog is the fast path, not the boundary. It holds the shapes that recur, so they resolve in
shell at no token cost. Most work does not fit a named shape.

### 1a. Composed flows

When no row fits, Polaris composes one. A composer agent reads the inventory, 27 fleet agents, 29
commands, and the workflows, and returns a phase list in the same shape a catalog row has. It is
seeded into the ledger identically and enforced identically, so nothing downstream knows or cares
whether a flow was named or composed.

This is Rule 5 on the sequence axis. The catalog is what code can decide; composition is the
judgment call, and it happens once per task rather than turn by turn. The failure mode today is
that the sequence is re-decided at every turn by whichever model holds the context, which is what
"at the mercy of the model" means in practice. Composing once and recording the result ends that.

`/synthesize` is the sibling on the capability axis: it composes an agent when no fleet agent fits.
The composer fills a sequence gap; `/synthesize` fills a capability gap. A composed flow may name
`command:synthesize` as one of its phases when both gaps appear in the same task.

Three constraints keep composition honest:

- **It composes, it does not invent.** Every phase must name an existing agent, command, or
  workflow. `scripts/check-flows.sh` validates a composed flow the same way it validates the
  catalog, and a flow naming a target that does not resolve is rejected before it is seeded.
- **It is announced before it runs.** The composed phase list is printed, and editing it is a
  sentence: drop a phase, add a review, reorder. A composed flow the user did not want is visible
  at phase zero rather than discovered at phase four.
- **Reuse promotes it.** A composed flow that gets used more than twice is written into
  `flows.json` as a row, matching how `/synthesize` keeps an ephemeral agent only once it proves
  useful. The catalog grows from observed work rather than from guessing.

### 2. The run ledger

`.polaris/runs/<slug>/state.json`, owned by `scripts/run-state.sh`, matching how
`sweep-window.sh` and `okr-pace.sh` already own their state.

```
{
  "slug": "referral-duplicates",
  "flow": "bug",
  "current": "rootcause",
  "record": {
    "reproduce": {
      "status": "done",
      "artifact": ".polaris/runs/referral-duplicates/reproduce.md",
      "sha256": "...",
      "evidence": "test/referrals.spec.ts:41 fails on duplicate insert",
      "at": "2026-08-01T09:14:22Z"
    }
  }
}
```

Subcommands: `get`, `seed <flow> <slug>`, `record <phase>`, `approve <phase>`, `assert <phase>`,
`clear`. `assert` is what the hooks call; it exits non-zero with a reason on stderr when the named
phase may not start.

Status alone would let a phase claim done, so the record carries evidence: `artifact` must exist,
`sha256` must match it, and `evidence` must hold the output of the check that passed it. That is
what makes Rule 12 enforceable rather than aspirational.

The human-readable run log at `.polaris/runs/<date>-flow-<slug>.md` stays. The ledger is machine
state; the log is the narrative.

### 3. Routing seeds the ledger

The entry point is not a command. `rules/routing.md` already holds a 12-row task-class table,
injected every session as advice nothing checks, and `hooks/enhance-prompt` already fires on every
prompt and reads the payload only to discard it. Joining them turns the table into behavior.

`enhance-prompt` classifies in two passes:

1. **Deterministic.** `rules/patterns.json` gains a `routing` section: per class, the trigger
   patterns that identify it. A prompt matching one class and no other is classified in shell at
   no token cost. This covers the common shapes.
2. **Composition.** When nothing matches or two classes tie, the composer builds a flow for this
   task from the inventory and seeds that. The prompt is never handed back unrouted, because
   handing it back is the fragmentation this spec exists to end. Composition costs one agent call
   against a catalog hit's zero, which is the reason the catalog exists.

**On a confident match the hook seeds the ledger.** This is the difference between routing and
advice. `additionalContext` is text the model may ignore; a seeded ledger is state the gates read
and enforce. Without the seed, Polaris only suggests better.

Seeding is bounded: one open run per project, a confident class only, and never for
`conversation`. A prompt arriving while a run is open is treated as input to that run, not as a
new one. `/polaris:pause` clears it, and the seeded flow is announced, so a misroute is visible
before it acts.

### 4. Enforcement

| Hook | Matcher | Refuses |
|---|---|---|
| `PreToolUse` | `Task` | Dispatching an agent the current phase does not name |
| `UserPromptExpansion` | the phase commands | Running a phase whose predecessor is not approved |
| `Stop` | — | Ending a session with an open phase, once per transition |
| `TaskCompleted` | — | Ticking a phase off before its evidence exists |

`UserPromptExpansion` receives `command_name`, `expanded_prompt`, and `cwd`, and blocks with a
top-level `{"decision": "block", "reason": "..."}`. `TaskCompleted` is the one event whose input
schema the hooks reference does not publish; it is additive, because the evidence check also runs
in the Stop hook.

### 5. The phase engine

The Stop hook advances the flow. After a phase finishes and the turn ends, it reads the ledger:

- phase done, `approve: true` → block, instructing the model to present the artifact and stop
- phase done, no approval needed → block, instructing it to run the next phase
- flow complete, or no run open → silent

The pauses land between phases, in conversation. That resolves the runtime constraint that a
workflow cannot take input mid-run: sign-off never needs to happen inside one.

It blocks at most once per transition, using the atomic-mkdir marker `stop-capture` proves out. A
gate with no exit gets switched off within a week, and a gate that is off enforces nothing.

### 6. Workflows, only where work fans out

A phase is one dispatch unless it fans out or loops to convergence. Three do, so three workflow
scripts ship under `workflows/` at the plugin root, namespaced `/polaris:<name>`:

- `review` — reviewers across the dimensions, then verification
- `verify` — the convergence loop shared by `bug`, `audit`, `qa`, and `security`
- `build` — implement, review, QA, until clean

Three quality patterns are the reason these are scripts and not prose:

**Loop until dry.** Keep running finders until two consecutive rounds surface nothing new, deduping
against every finding seen rather than the confirmed set. `flow.md` caps at 3 rounds by asking the
model to count, which stops whether the work converged or not. A ceiling stays as a runaway guard.

**Diverse verification.** Each finding goes to three verifiers with different lenses (correctness,
security, does-it-reproduce), each prompted to refute, surviving on a majority. Three identical
verifiers catch less than three different ones. The over-engineering axis stays mandatory.

**Judge panel on architecture.** The `feature` flow's design phase drafts three independent
architectures and scores them with parallel judges, then synthesizes from the winner. `flow.md`
fans out five specialists who each own a slice, so no agent ever proposes a competing whole; the
specialists run after the shape is chosen, against it.

Every `agent()` call passes `opts.agentType` naming a fleet agent. Without it the runtime spawns a
generic subagent and the tool restrictions added to the fleet in 1.9.0 do not apply. Model and
effort come from `rules/model-routing.md` via `opts.model` and `opts.effort`, which turns a policy
nothing enforced into per-stage code.

### 7. The clarity veto

`hooks/enhance-prompt` today injects a directive asking the session model to judge whether the
prompt is clear. That judgment was meant for a cheap model. A `type: "prompt"` hook is that job,
run on Haiku before the expensive model reads anything.

Prompt hooks return only `{"ok", "reason"}` and cannot emit `additionalContext`, so the cheap model
can veto but not route. On `UserPromptSubmit`, `ok: false` ends the turn with the reason as a
warning line, so the veto stays conservative: it fires only when the prompt names neither a target
nor an action, and the reason carries the sharpened restatement, since that is the only text the
user sees.

## Not in scope

- **Agent teams.** A second orchestrator buys nothing the Stop-hook engine does not already do.
- **Checkpointing.** Git covers revert, and Polaris work happens on main.
- **`PostToolBatch`.** No gate needs to stop the agentic loop mid-turn.
- **The sweep family.** `/sweep`, `/journal`, `/track`, and `/catchup` are script-backed already
  and have no ordering problem to solve.
- **Rewriting the 29 commands.** Flows compose them as they are.

## Risks

- **`SubagentStart` may not fire for workflow-spawned agents.** `inject-standard` is how the
  Polaris standard reaches every agent. If it does not fire inside a workflow, those agents work
  without it and quality drops with no visible symptom. This must be tested before any phase moves
  out of a `Task` dispatch. If it does not fire, each workflow prompt carries the standard.
- **Workflow subagents always run in `acceptEdits`,** regardless of session permission mode. File
  edits inside a phase are auto-approved, which is the reason `ship` keeps its outward-facing
  confirmations in the command layer rather than the script.
- **Misroutes.** Patterns over natural language will put a feature in the `fix` class. The `unknown`
  fallthrough and the announced seed bound the cost; they do not prevent it.
- **`TaskCreated` and `TaskCompleted` schemas are undocumented,** so both are additive above.
- **The installed plugin cache lags this repo,** so no hook behavior here is proven by the test
  suite alone. Every layer needs an update-and-test cycle.

## Test plan

- `scripts/run-state.sh`: fixture tests for seed, record, approve, `assert` failing on an
  unapproved predecessor and passing on an approved one, and `record` rejecting a missing artifact
  or a hash mismatch.
- `scripts/route-prompt.sh`: a fixture of `class<TAB>prompt` cases, at least two per flow, five
  conversation cases that must route nowhere, and three ambiguous ones expected to yield `unknown`.
- A hook test that `PreToolUse` denies a `backend` dispatch against a ledger whose current phase is
  `spec`, and allows it at `build`.
- A live test that a Stop-hook block fires once and not twice for the same transition.
- A live workflow run confirming whether `SubagentStart` fires for its agents.
- `flows.json` validated against the fleet and the command directory: every `run` target exists.

## Build order

Routing and the ledger ship together. Routing alone emits text the model may ignore; the ledger is
what the gates read. Shipping the advisory half first would prove nothing.

1. `rules/flows.json`, the catalog, and a validator that every `run` target exists.
2. `scripts/run-state.sh` and its tests.
3. `scripts/route-prompt.sh` and its fixture set.
4. `enhance-prompt` reads the prompt, classifies, seeds the ledger, and announces the flow.
5. The `PreToolUse` gate and the Stop engine, proving enforcement end to end on the `bug` flow.
6. The composer, so a task matching no row still gets a flow.
7. The clarity veto on the small model.
8. The three workflows, and the `UserPromptExpansion` gate over the phase commands.
9. The statusLine, and `disable-model-invocation` on the phase commands.

The composer lands after the gates on purpose. Composition is only worth building once a seeded
flow is provably enforced, and the catalog covers enough of the day to prove it.
