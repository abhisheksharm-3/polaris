# Flow run — daily signal sweep

- **Task:** A twice-daily feature that pools all sources (Gmail, Slack, Jira, Fathom transcripts,
  Calendar) in entirety, analyzes each, extracts every task including buried signals, and produces
  durable output (tasks and/or a morning report) so nothing is missed. Successor to the nascent
  `/catchup`.
- **Date:** 2026-07-20
- **Config:** mode=custom, deadCode=delete, backwardCompat=none.

## Timeline

- Phase 0 (intake) — read config + `commands/catchup.md`; confirmed no Google Tasks connector
  (Calendar/Drive/Gmail/Slack/Jira/Fathom/Notion only); flagged headless-connector-auth risk for
  unattended runs. Opened decision round with the human on output form, trigger model, recall/noise.
- Phase 0 (decisions) — human locked: output = Notion per-day subpages under a parent; trigger =
  manual command; recall = two tiers. Feasibility clean on paper, no spike needed.
- Phase 1 (spec) — dispatched `product` (opus). After one premature stop, wrote
  `.polaris/specs/2026-07-20-signal-sweep-spec.md`: `/dispatch` command, 5-step run, two-tier recall,
  carry-forward with live re-check, `--dry-run` seam, given/when/then criteria, four-persona pass.
- Phase 1 (gate) — human approved; three forks defaulted (name `/dispatch`, two subpages/day,
  group by lists). Decided to keep `/catchup`, revisit deletion after `/dispatch` is dogfooded.
- Phase 2 (design) — downshifted and collapsed into the plan: no API/schema/UI; spec already fixed
  structure, data shapes, Notion layout, and security posture. Carry-forward heuristics deferred to
  the plan.
- Phase 3 (plan) — wrote `.polaris/plans/2026-07-20-signal-sweep.md` via writing-plans skill. Two
  build decisions surfaced: renamed `/dispatch`→`/sweep` (validator collision on "dispatch"), and
  pulled window/cap date math into a tested shell helper `scripts/sweep-window.sh` per Rule 5.
  Three tasks: helper+tests (TDD), command file, routing. Self-reviewed; fixed a carryMaxDays vs
  maxLookbackHours conflation. Behavioral criteria flagged as QA-verified, not unit-tested.
- Phase 3 (gate) — human approved, confirmed `/sweep` name.
- Phase 4 (implement) — inline TDD. Task 1: `scripts/sweep-window.sh` + 3 tests, all green
  (commit 0147014). Task 2: `commands/sweep.md`, check-commands + prose + suite green. Task 3:
  `/sweep` row in `commands/route.md`. Three commits on main.
- Phase 5 (review) — dispatched two `reviewer` agents (correctness+simplicity, security). No
  blocker/high correctness; two security-High (write-scope + injection are in-prompt only, not
  mechanically enforced), plus lows. Fixed in one round: helper now falls back to first-run on a
  future/unparseable cursor (2 new regression tests); command hardened with fixed write-target and
  state-path invariants, live-Jira Fathom resolution, helper-failure guard, and a non-atomic
  page/state-write dedup rule; corrected the spec's stale `+05:30` example to UTC Z. Suite green,
  prose green (commits e-series). Residual: write-scope is advisory in a markdown command.
- Phase 6 (QA) — deterministic core covered by the 5 window unit tests. Behavioral QA (extraction,
  tiering, carry-forward, injection) needs the user's live connectors + a real Notion page; handed
  off as a `--dry-run` acceptance checklist rather than faked here.
- Phase 7 (docs) — README table row + workflow line, CHANGELOG 1.5.0 entry, route row (Phase 4).
- Phase 8 (ship) — main-only, no PR. Version bumped to 1.5.0 in plugin.json + marketplace.json.
  5 commits on main, ahead of origin/main; push awaiting user confirmation.
- Phase 9 (operate) — N/A (markdown command, no deploy or runtime observability).

## Outcome

Built and committed on main (`0147014`→`a3f41bd`), version 1.5.0. Not pushed (awaiting confirmation).
Report: `.polaris/reports/2026-07-21-signal-sweep.md`. Spend: telemetry off, not recorded.
