# Work streams

<!-- The Polaris work tracker for this project. Surfaced at session start; updated by /track. -->
<!-- Keep active and blocked streams at the top. Move finished ones to the Done archive. -->

## flow-enforcement — make routing bind instead of suggest

- domain: feature
- status: active
- state: Tasks 1 through 5 are built and committed. `rules/flows.json` holds the flow catalog with
  `scripts/check-flows.sh` asserting every phase target resolves. `scripts/run-state.sh` is the run
  ledger, one open run per project, a phase done only with its artifact on disk and its hash
  matching. `scripts/route-prompt.sh` classifies a prompt against the `routing` array in
  `rules/patterns.json`, with `tests/fixtures/routing-cases.txt` as the fixture set.
  `hooks/enhance-prompt` reads the prompt, routes it, and seeds the run. `hooks/guard-phase` refuses
  an out-of-phase `Task` dispatch and `hooks/advance-flow` drives the flow at `Stop`, both
  registered in `hooks/hooks.json`. `commands/pause.md` clears an open run. The preflight and the
  first cache sync emptying the install are recorded in `.polaris/runs/`.
- next: finish Task 6, live verification of the bug flow. Steps 2, 4, and 5 are confirmed from a
  live session: a described bug announced the `bug` flow and opened the ledger at `reproduce`,
  `advance-flow` blocked once at `Stop` naming the phase, and `/polaris:pause` cleared the run.
  Step 3 is unproven, no out-of-phase dispatch was attempted, so `guard-phase` has only its suite
  coverage. Steps 1, 6, and 7 remain. Then Task 7, the flow composer.
- files: rules/flows.json, rules/patterns.json, scripts/check-flows.sh, scripts/route-prompt.sh,
  scripts/run-state.sh, hooks/enhance-prompt, hooks/guard-phase, hooks/advance-flow,
  hooks/hooks.json, commands/pause.md, tests/fixtures/routing-cases.txt, tests/run-tests.sh,
  templates/config.default.json, docs/specs/2026-08-01-flow-enforcement.md,
  docs/plans/2026-08-01-flow-enforcement.md,
  .polaris/runs/2026-08-01-flow-enforcement-preflight.md
- touched: 2026-08-01 (routing, run ledger, phase guard, Stop driver, and a live bug-flow probe)

## Done

- gaps — closed the top three plan-vs-code gaps from the 2026-07-15 research report, and the three
  changes are committed (873d34c, 793a357). The master plan §3 no longer claims all-built and §3.4
  lists what is designed but unbuilt. The work tracker auto-maintains from a session-start
  reconcile, and /flow writes run history to .polaris/runs/. The remaining §3.4 items (monitors,
  cost meter, /schedule, connectors, embeddings RAG) stay deferred, low value at one user until a
  felt need.
- The revamp into an all-in-one project OS: M1 quality foundation, M2 handoff/audit docs, M3 fleet +
  routing + guardrails, M4 orchestration cycle + standalone modes, M5 prompt-enhance + dynamic
  synthesis, the work-tracker MVP, subsystem E file memory, the diagnostic modes, and the daily
  journal. Shipped across releases up to v1.2.1; each has a spec and plan in docs/.
