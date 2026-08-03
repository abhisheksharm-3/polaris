# Docs drift, 2026-08-03

The 1.10.0 flow work moved the definition of a flow from prose into `rules/flows.json` and added
five scripts, three hooks, and a workflows directory. Four docs still described the shape before it.

## Fixed

| Doc | Drift | Fix |
|---|---|---|
| `commands/flow.md` | Declared eleven phases; the `feature` row it backs has four. Two definitions of one flow, and the ledger knew only one | Rewritten to open the `feature` run and run its first phase. 99 lines to 44 |
| `rules/doc-organization.md` | Said `runs/` holds dated markdown. It also holds `<slug>/state.json`, `.open`, and `.composed-log`, the files every gate reads | Layout documented, with a line saying `run-state.sh` owns them and a hand edit breaks the artifact hash |
| `commands/route.md` | Missing `/compose`, `/pause`, `/init`, `/journal`, `/notes`, `/onboard`; framed routing as something a human types | Rows added, and a paragraph saying the router now runs on every prompt |
| `CLAUDE.md` | Missing `workflows/`, five scripts, three hooks, `flows.json`, `model-floor.json`, and the `routing` config key | All added, plus four gotchas |

The `commands/flow.md` conflict was the one that would actively mislead: a model reading it would
have run an eleven-phase cycle the ledger has no phases for, and `advance-flow` would have asked for
a phase the command never mentions. `rules/flows.json` is the tested and enforced definition, so the
prose defers to it and says so.

## Flagged, not fixed

`docs/POLARIS_MASTER_PLAN.md` still calls `/flow` the full orchestration cycle at line 822 and
describes the cycle at line 794. That file is a plan, a record of what was intended, and rewriting
intent to match the outcome erases the history that makes it useful. A human should decide whether
it gets an addendum or stays as written.

## Not drift

`README.md` was updated with the flow catalog in the same release. `rules/routing.md` documents the
router and the veto. Both match the shipped code.
