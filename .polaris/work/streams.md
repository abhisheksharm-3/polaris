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
  The docs now match that shape: a 2026-08-03 drift pass rewrote `commands/flow.md` from eleven
  prose phases down to 44 lines that defer to the `feature` row, documented the `runs/<slug>/`
  layout in `rules/doc-organization.md`, added the six missing rows to `commands/route.md`, and
  brought `CLAUDE.md` up to the shipped architecture. 1.10.0 is dated in `CHANGELOG.md` with
  release notes in `.polaris/releases/2026-08-03-v1.10.0.md`.
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
- open question, for a human: `docs/POLARIS_MASTER_PLAN.md` still calls `/flow` the full
  orchestration cycle at line 822 and describes that cycle at line 794. Left as written on the
  argument that a plan records intent and rewriting it erases the history. Decide addendum or
  leave.

## sweep-briefing-format — restructure what /sweep emits

- domain: feature
- status: blocked, on a human approval
- state: The spec is written and was recorded: `.polaris/specs/sweep-briefing-format.md`, 503 lines,
  `check-patterns.sh prose` exit 0. The run then reached its approval stop and was cleared with
  `scripts/run-state.sh clear` to free the one-open-run slot for `review-levels`, so the ledger no
  longer holds it. The spec file is untracked but on disk. The request is structure and information
  density, not which sources are read. The evidence is one real briefing: 40 bullets under a single
  `Act on this` heading with no priority order, four preamble blockquotes and three closing essays
  that restate the bullets, deadlines stated in prose with nothing collecting them by date, and
  `day N` ages that nothing escalates on.
- next: re-seed the run with `scripts/run-state.sh seed feature sweep-briefing-format`, re-record
  the spec against the same artifact, and read it for approval. `design` also stops for approval
  before any edit to `commands/sweep.md`.
- files: commands/sweep.md, scripts/sweep-window.sh, scripts/okr-pace.sh,
  .polaris/specs/sweep-briefing-format.md
- touched: 2026-08-03 (spec written and recorded, then the run was cleared unapproved)

## review-levels — make /polaris:review cost what the job is worth

- domain: feature
- status: active
- state: The `feature` run under `.polaris/runs/review-levels/` has spec and design done and
  approved; the ledger's `current` is `build`. `workflows/review.js` now carries the `LEVELS` table,
  the coerced-string level resolution, the batched per-dimension Confirm stage, and the trimmed
  `meta` block (Plan Steps 1-7); `CHANGELOG.md` carries the `1.11.0` entry (Step 8); the README needed
  no edit since it documents only `/review-pr` and no workflow name (Step 9). Steps 10 (the
  four-level acceptance run) and 11 (commit) are still outstanding, and nothing here is committed
  yet.
- next: run Step 10's four acceptance passes against a real changeset, then commit per Step 11 and
  record the `build` phase in the ledger with `scripts/run-state.sh record build ...`.
- files: workflows/review.js, hooks/guard-review, rules/flows.json, CHANGELOG.md
- touched: 2026-08-03 (spec and design approved; Steps 1-9 implemented, uncommitted)
- open question, for a human: `.polaris/plans/review-levels.md` uses `- [ ]` checkboxes as its
  resume ledger, but the plan artifact's sha256 is locked in as the design phase's evidence in
  `.polaris/runs/review-levels/state.json`; ticking a box after design is recorded invalidates that
  phase under the run-ledger rule ("an artifact edited after the fact invalidates the phase that
  claimed it"). Progress after design is recorded is tracked here and in the run ledger, not by
  editing the checkboxes. Decide whether the plan template should stop carrying checkboxes once a
  plan is hash-locked, or whether the ledger should hash phases instead of whole files.

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
