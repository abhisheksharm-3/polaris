# Work streams

<!-- The Polaris work tracker for this project. Surfaced at session start; updated by /track. -->
<!-- Keep active and blocked streams at the top. Move finished ones to the Done archive. -->

## flow-enforcement — make routing bind instead of suggest

- domain: feature
- status: active
- state: All eleven tasks are built and committed, version 1.10.0 in both manifests, suite at 185
  assertions. `rules/flows.json` holds eighteen flows, each an ordered phase list, with
  `scripts/check-flows.sh` asserting every target resolves. `scripts/run-state.sh` is the ledger: a
  phase is done only with its artifact on disk and its hash matching, one open run per project.
  `hooks/enhance-prompt` classifies every prompt against the `routing` array in
  `rules/patterns.json` and opens the run; `/polaris:compose` builds a flow from
  `scripts/inventory.sh` when no row fits, validated and gated like a catalog row. Four gates read
  the ledger: `guard-phase` refuses an out-of-phase dispatch and one below the floor in
  `rules/model-floor.json`, `guard-command` refuses a phase command whose predecessor is unearned,
  `advance-flow` drives the run at `Stop`, and the small-model veto refuses an unactionable prompt.
  Three workflows under `workflows/` hold the fan-out. `/polaris:pause` clears a run and
  `scripts/statusline.sh` shows it.
- next: two gaps, both needing a live session rather than the suite. An observed deny: every
  `guard-phase` and `guard-command` assertion is a hand-built payload, and the `Task` versus `Agent`
  matcher bug is exactly what that gap produces. And whether `SubagentStart` fires for
  workflow-spawned agents, which decides whether `inject-standard` reaches them; answering it means
  running `/polaris:verify` once. Nothing is pushed, and the installed plugin holds the working tree
  under `polaris/1.8.0/`.
- files: rules/flows.json, rules/model-floor.json, rules/patterns.json, rules/routing.md,
  scripts/check-flows.sh, scripts/route-prompt.sh, scripts/run-state.sh, scripts/inventory.sh,
  scripts/statusline.sh, hooks/enhance-prompt, hooks/guard-phase, hooks/guard-command,
  hooks/advance-flow, hooks/hooks.json, commands/pause.md, commands/compose.md,
  workflows/verify.js, workflows/review.js, workflows/build.js,
  tests/fixtures/routing-cases.txt, tests/run-tests.sh, templates/config.default.json,
  README.md, CHANGELOG.md, .claude-plugin/plugin.json, .claude-plugin/marketplace.json,
  docs/specs/2026-08-01-flow-enforcement.md, docs/plans/2026-08-01-flow-enforcement.md,
  .polaris/runs/2026-08-01-flow-enforcement-preflight.md
- touched: 2026-08-01 (the composer, the clarity veto, three workflows, the command gate, the model
  floor, and the 1.10.0 changelog)

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
