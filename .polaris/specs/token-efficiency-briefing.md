# Token efficiency: the research briefing

Input to the `token-efficiency` run's spec phase. Facts gathered 2026-08-03 from the repo and from
the Claude Code documentation. Every number here is measured or quoted, not estimated, and the two
estimates are labelled as such.

## The complaint

A single `/polaris:review` costs roughly half a session limit. The `level` argument added in 1.10.0
helps only when the user remembers to pass it, so the expensive path is the default path. Polaris
should hold its quality while costing a fraction of what it costs now.

## What a default review actually dispatches

`workflows/review.js` with no `level` resolves to `high`:

- 7 dimensions, so 7 reviewer agents, at `effort: 'high'`.
- Up to 7 verifier agents in the Confirm stage, one per dimension with findings, since `high`
  confirms both `high` and `medium` severities.
- 14 agents at the ceiling.

Per `rules/model-floor.json`, 12 of those 14 are floored at **opus**: `reviewer` (used by
`correctness`, `maintainability`, `over-engineering`), `security-architect`, `tester`, and
`verifier` on all 7 confirm slots. Only `perf` and `ux` are sonnet.

## The cost model, corrected by the documentation

The first draft of this analysis assumed the model tier was the dominant multiplier. The
documentation says otherwise, and the correction matters enough to rewrite the priority order.

From `https://code.claude.com/docs/en/prompt-caching.md`:

- "A subagent starts its own conversation with its own system prompt and tool set, separate from the
  parent's. It builds its own cache, starting with **no cache hits on its first call** and warming
  up across its own turns."
- "Subagents use the **five-minute TTL** even on a subscription, since the automatic one-hour TTL
  applies to the main conversation."
- "A **fork**, by contrast, inherits the parent's system prompt, tools, and conversation history
  exactly, so its first request reads the parent's cache."
- Cache is keyed by model and by effort level, and each has its own cache.

From `https://code.claude.com/docs/en/costs.md`:

- "Teammates load CLAUDE.md, MCP servers, and skills automatically, but everything in the spawn
  prompt adds to their context from the start."
- Thinking tokens are billed as output tokens, and the default budget "can be tens of thousands of
  tokens per request". Lower it with effort levels, or `MAX_THINKING_TOKENS` on fixed-budget models.
- `/usage` attributes recent usage to skills, subagents, plugins, and individual MCP servers, and
  flags any behavior accounting for 10% or more. `d` and `w` switch between 24 hours and 7 days.

Three consequences:

1. **Agent count is the dominant term, not model tier.** Each of the 14 agents pays a full uncached
   read of its own system prompt, tool definitions, CLAUDE.md, and the `inject-standard` payload
   before it reads any diff. Halving the agent count halves that fixed cost outright.
2. **Mixing model tiers across a fan-out is cache-neutral.** Each subagent has its own cache
   regardless, so a sonnet reviewer beside an opus one costs nothing extra in cache terms. The
   model-switch penalty the docs describe applies to switching within one conversation, which a
   fan-out never does. The decision to let the floor follow the level is safe on this axis.
3. **Effort is billed as output tokens.** `effort: 'high'` on 7 reviewers is a large output bill
   independent of the input side, and it has its own cache key.

## What is already efficient, and should not be touched

Establishing this matters as much as the findings, because a change here would be cost with no
saving:

- `hooks/inject-standard` injects a 1.6KB summary, not the 10KB `rules/core.md`. It fires only for
  code-writing and reviewing agents; the rest exit early. Cheap and correctly scoped.
- MCP tool definitions are deferred by default, so the connected servers cost tool names rather than
  full schemas until used.
- `CLAUDE.md` is roughly 150 lines, inside the documented 200-line guidance.
- The Confirm stage already batches one verifier per dimension rather than one per finding, and
  already skips a dimension that returned nothing.
- `pipeline()` rather than a barrier, so a slow reviewer does not hold up a fast one's confirmation.

## The levers, in the order the evidence supports

### 1. Choose the level from the diff, not from the user

The default is `high`, which makes the worst case the common case. The inputs needed to pick a level
are free and deterministic, and `CLAUDE.md` Rule 5 says code answers this rather than a model:

- `git diff --numstat` gives files touched and lines added and deleted.
- Paths give risk. A migration, an auth or payment path, or a dependency manifest escalates. A
  docs-only or test-only diff drops.

The explicit `level` argument stays as an override, so a human can always force `critical`.

Open question for the spec: the exact thresholds, and whether the risk-path list is configurable in
`.polaris/config.json` or fixed in the workflow.

### 2. Let the model floor follow the level

`rules/model-routing.md` pins review and adversarial work to opus unconditionally. That policy was
written when a review was one agent. It now multiplies by 14. The floor should be a function of the
level: sonnet reviewers at `low` and `mid`, opus at `high`, opus everywhere at `critical`.

This is the only lever that can cost quality, and it is the reason the spec needs a
before-and-after measurement rather than an assertion that quality held.

`hooks/guard-phase` enforces the floor at dispatch and `tests/run-tests.sh` asserts the refusal, so
both move with this change.

### 3. Pack the evidence once

Each reviewer independently runs `git diff` and reads the same files, so the exploration turns are
paid 7 or 14 times over. One cheap prepack stage that hands every reviewer identical evidence
removes those turns.

Stated honestly: the diff text still appears once per agent as prompt input, so this is not a 14x
cut on the input side. It saves the exploration turns and the thinking tokens around them, and it
makes reviewers more consistent because they judge identical evidence. The documentation endorses
the shape under "Offload processing to hooks and skills".

### 4. Confirm only what changes an action

At `high`, Confirm covers `high` and `medium` severities. A `medium` finding that the reviewer
already described with a file, a line, and a fix may not need an opus verifier to decide it is real.
Candidates: confirm `high` always, confirm `medium` only when the reviewer's own confidence is low,
and never spend an agent to confirm a finding whose fix is smaller than the verdict.

## Non-goals

- No change to what the `over-engineering` dimension is or its mandatory status. `hooks/guard-review`
  deadlocks without it and every level must keep it.
- No new agent, and no new hook. The saving comes from dispatching fewer and cheaper agents, not from
  adding machinery to manage them.
- Not a rewrite of `verify.js` or `build.js` in this run unless the level concept transfers cleanly;
  decide that in the design phase.
- No change to the flow catalog in `rules/flows.json`.

## The measured baseline, which reorders everything above

Taken from `/usage` on 2026-08-03, after the levers above were drafted. The weekly figures are what
the tool calls "independent characteristics of your usage, not a breakdown", so they overlap and do
not sum to 100.

Last 7 days, weekly limit at 30% used:

| Characteristic | Share |
|---|---|
| Usage at over 150k context | 67% |
| Subagent-heavy sessions | 42% |
| Plugin `polaris` | 21% |
| Four or more sessions running in parallel | 18% |

Attributed per subagent: `polaris:review` 6%, `polaris:flow` 3%, then `tester`, `reviewer`,
`verifier`, and `keel:code-reviewer` at 1% each. Per skill: `/polaris:sweep` 3%, `/polaris:flow` 2%,
then `journal`, `docs-drift`, and `release` at 1% each.

The session that produced this briefing: 47% of the session limit, $4.86, one product subagent. On
opus, 31.7k output tokens and 194.7k cache **write** against 4.5m cache read.

Three corrections follow, and the third is the one that matters:

1. **Review fan-out is 6% of the week, not the bulk of it.** The complaint that one review costs half
   a session is true per session and still worth fixing, but the four levers above target roughly a
   sixteenth of the actual drain. Sizing them as the answer would have been wrong.
2. **Long context is the dominant term at 67%.** Every request carries the whole conversation, so a
   long session pays for its history on every turn even at the cached rate.
3. **Polaris makes long context worse, and its own design already holds the fix.** `session-start`
   injects roughly 42KB before the first prompt. `enhance-prompt` appends routing context to every
   prompt. The `feature` flow then runs spec, design, build, and ship as one continuous conversation.
   The run ledger under `.polaris/runs/<slug>/state.json` exists precisely so a run survives a
   `/clear`, and nothing anywhere tells the user to use it that way. A flow that cleared context at
   each approval stop would cut the 67% term without touching quality, because the ledger, the spec,
   and the plan already carry everything the next phase needs.

A fourth, smaller one: 18% came from four or more parallel sessions sharing one limit. That is
behavioral rather than a Polaris defect, but `scripts/statusline.sh` already knows the open run and
could surface the parallel-session count beside it.

## How success is measured

Estimates are not acceptable evidence here, because the whole complaint is that the real cost
exceeded what the design implied. The spec must require:

1. A baseline from `/usage` over the last 7 days, with the subagent share recorded.
2. The same review target run before and after, with agent count, model tier per agent, and the
   `/usage` session figure captured for each.
3. A quality check that the cheaper run still finds the findings that mattered: run the reduced
   configuration against a target with known findings and confirm none of the high-severity ones
   were lost.

A configuration that saves tokens and drops a high-severity finding has failed, not succeeded.
