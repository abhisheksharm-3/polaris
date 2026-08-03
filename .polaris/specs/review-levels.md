# Review levels

Status: ready to build. No unresolved assumptions block the change.
Scope: `workflows/review.js` (84 lines), plus the docs listed under "Docs that go stale".

## The problem

`workflows/review.js` fans out 7 dimensions at `effort: 'high'`, then spawns one verifier per
finding. Seven dimensions raising five findings each is 7 + 35 = 42 agents in one run. The
per-finding fan-out has no ceiling, so the cost of a run cannot be predicted before it starts. The
user reports a single `/polaris:review` consuming 40-50% of a session.

Two coupled changes fix it: a `level` argument that picks a smaller set of dimensions and a lower
effort, and a Confirm stage that batches per dimension instead of per finding.

## The level table

This table is the normative source of truth. Code holds it as one data structure; prose elsewhere
defers to it.

| level | dimensions | effort | confirm |
|---|---|---|---|
| `low` | correctness, over-engineering | `low` | none, findings reported unconfirmed |
| `mid` | correctness, over-engineering, security, tests | `medium` | high severity only |
| `high` | all 7 | `high` | high and medium |
| `critical` | all 7 | `high` | every finding, 3 refutation lenses each |

`level` is read from `args.level`, the same way `args.target` is read today at `review.js:38`.
Default is `high`, so an existing dispatch of `workflow:review` keeps its current dimension set and
effort, and only its Confirm stage changes shape.

## Batched confirm

One verifier per dimension, given that dimension's whole eligible finding list, returning a verdict
per finding. At `critical`, three verifiers per dimension, one per refutation lens, and a finding
survives on a majority of the lenses that returned. Majority matches `workflows/verify.js:110`;
Polaris already aggregates three lenses that way, so this adds no second rule.

A dimension with no eligible findings spawns no verifier.

## Agent counts

Ceilings, with `d` dimensions that raised at least one eligible finding:

| level | reviewers | verifiers | worst case |
|---|---|---|---|
| `low` | 2 | 0 | 2 |
| `mid` | 4 | `d` (0-4) | 8 |
| `high` | 7 | `d` (0-7) | 14 |
| `critical` | 7 | `3d` (0-21) | 28 |

Today's worst case is unbounded. Every level above has one.

## Acceptance criteria

**AC1.** Given `args.level` is `low`, when the workflow runs, then exactly 2 agents are dispatched,
labelled `review:correctness` and `review:over-engineering`, and no agent carries `phase: 'Confirm'`.

**AC2.** Given `args.level` is `low` and the reviewers raised 4 findings, when the workflow returns,
then the object has `unconfirmed` holding all 4 findings and has no `confirmed` key at all.

**AC3.** Given `args.level` is `mid`, when the reviewers run, then 4 reviewers are dispatched
(correctness, over-engineering, security, tests) and each is called with `effort: 'medium'`.

**AC4.** Given `args.level` is `mid` and one dimension raised 2 high and 3 medium findings, when
Confirm runs, then that dimension dispatches exactly 1 verifier, its prompt names both high findings
and neither medium one, and the 3 medium findings appear in `unconfirmed` in the returned object.

**AC5.** Given `args.level` is `high` and a dimension raised 1 high, 1 medium, and 1 low finding,
when Confirm runs, then 1 verifier judges the high and the medium finding, and the low finding
appears in `unconfirmed`.

**AC6.** Given `args.level` is `critical` and 2 dimensions each raised findings, when Confirm runs,
then 6 verifiers are dispatched, 3 per dimension, and the 3 prompts for one dimension differ only in
the refutation lens they name.

**AC7.** Given `args.level` is `critical` and a finding is refuted by 2 of 3 lenses, when the
workflow returns, then that finding is in `refuted` and not in `confirmed`.

**AC8.** Given any of the 4 levels, when the reviewers are dispatched, then one of them is labelled
`review:over-engineering`. (`hooks/guard-review:9` blocks a report that omits the axis, so a level
that dropped it would deadlock the reviewer.)

**AC9.** Given a dimension whose reviewer returned zero findings, when Confirm runs, then no
verifier is dispatched for it.

**AC10.** Given `args` has no `level` key, when the workflow runs, then it behaves as `high`: 7
reviewers at `effort: 'high'`, Confirm over high and medium findings.

**AC11.** Given `args.level` is `LOW`, `urgent`, `""`, or `null`, when the workflow runs, then it
resolves to `high` through a table lookup in code with no model call, and logs the rejected value.

**AC12.** Given any level, when the workflow returns, then the object carries `level` set to the
resolved level and `reviewed` listing exactly the dimension keys that ran.

## Testing seams

Two, both existing:

1. The returned object. Nothing consumes it programmatically (`rules/flows.json:151` dispatches
   `workflow:review` and reads nothing back), so AC2, AC5, AC7, AC10, and AC12 are checked by
   reading the returned JSON of a run.
2. The `label`, `phase`, and `effort` fields on each `agent()` call, visible in the run log. AC1,
   AC3, AC4, AC6, AC8, AC9, and AC11 are checked there.

No new seam, no new test script. `tests/run-tests.sh` runs pattern checks over files; it does not
execute workflows, and this change does not add an executor for one.

## Scope and non-goals

In scope: `workflows/review.js`, and the doc lines below that state a dimension count or describe the
Confirm stage.

Non-goals:

- No new file, agent, script, or hook.
- No change to `rules/flows.json`. The `review` flow keeps dispatching `workflow:review` with no
  level, and takes the `high` default.
- No change to `verify.js` or `build.js`.
- No level argument on `/polaris:review-pr`. That command is prose-driven and separate.
- No cost telemetry, no token accounting, no per-level budget enforcement. The ceilings above are
  arithmetic on the table, not a runtime check.
- No `severity` schema change. The existing `high | medium | low` enum drives the confirm thresholds.

## Docs that go stale

| File | Line | Why |
|---|---|---|
| `workflows/review.js` | 3-8 | `meta.description` and the two phase details describe every dimension and per-finding confirm. Both become wrong, and `meta` feeds the skill listing. |
| `CHANGELOG.md` | top | Needs a new entry for the level argument and the batched confirm. Line 26 records what 1.10.0 shipped and stays as written. |
| `README.md` | 112, 187-193 | Describes reviewing "across dimensions" with no level. Add the argument where the command is listed. |

Checked and not stale: `CLAUDE.md:103` names the three workflows without dimension counts.
`agents/reviewer.md:4` lists lenses the agent supports, which the level does not change.
`.polaris/releases/2026-08-03-v1.10.0.md:50` is a shipped release record, left alone.

## Open questions

None. The two decisions that could have been guesses are settled above: the `critical` aggregation
rule follows `verify.js:110` majority, and an unrecognized level falls back to `high` rather than
failing the run, because a review that refuses to start is worse than one that runs the default.
