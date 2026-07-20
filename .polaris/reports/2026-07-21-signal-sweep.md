# Flow report — signal sweep (`/sweep`)

**Date:** 2026-07-21. **Outcome:** built and committed on `main` (5 commits, `0147014`→`a3f41bd`),
not yet pushed. Version bumped 1.4.0 → 1.5.0.

## What was built

`/sweep`, a manual command run at a start-of-day or end-of-day calendar block. One run pulls Gmail,
Slack, Jira, Fathom, and Calendar in full over a bounded window, extracts every action item and
every buried signal into two tiers ("act on this" / "worth a glance"), groups them by
configured lists, carries unresolved items forward from the prior run, and writes one dated Notion
subpage. It is the deep, durable successor to `/catchup`, which stays as the fast skim.

Files:

- `commands/sweep.md` — the command.
- `scripts/sweep-window.sh` — deterministic window/cap helper (date math kept out of the model per
  core-standard Rule 5), with 5 unit tests in `tests/run-tests.sh`.
- `commands/route.md`, `README.md`, `CHANGELOG.md` — discovery and docs.
- `.claude-plugin/plugin.json`, `marketplace.json` — version 1.5.0.

Design record: spec `.polaris/specs/2026-07-20-signal-sweep-spec.md`, plan
`.polaris/plans/2026-07-20-signal-sweep.md`, run log `.polaris/runs/2026-07-20-flow-daily-signal-sweep.md`.

## Decisions, cleared with the user

- Output is a Notion per-day subpage (no Google Tasks — no connector exists for it). Trigger is
  manual (no cron — sidesteps the headless connector-auth problem). Recall is two-tier so a subtle
  signal is never dropped, only tiered.
- Renamed `/dispatch` → `/sweep` during planning: the name collided with `check-commands.sh` and the
  plugin's "dispatch an agent" concept, and `/sweep` matches the `sweep` config block.

## Found and fixed (review, one round)

Two `reviewer` agents (correctness+simplicity, security). No blocker or high correctness finding.
Fixed:

- Helper returned an inverted window on a future/clock-skewed cursor and crashed on an unparseable
  one. Now both fall back to a first run. Two regression tests added.
- Command hardened: the write-target page id and the state path are stated as run-fixed invariants
  no source content can change; Fathom resolution requires a live Jira query, not a transcript
  claim; a helper-failure guard; and a dedup rule for the page-written-but-state-write-failed case.
- Corrected the spec's stale `+05:30` state example to the UTC `Z` the helper actually parses.

## Accepted, with rationale

- **`carryMaxDays` age-out (default 14 days)** is beyond the original spec. Added at plan stage (and
  approved) to bound infinite carry of Fathom items that have no machine-readable done-signal. Named
  as a known ceiling with an upgrade path.
- **`allowed-tools` omits the MCP connector and Notion tools.** This matches the proven
  `commands/catchup.md` convention (Rule 11); those tools resolve at session level. The security
  reviewer flagged the conflict; resolved toward the working precedent.
- **No static config-block check** (a spec testing-seam suggestion): the `sweep` block lives in the
  user's project config, not this repo, so there is nothing here to check statically. The command
  validates the config at runtime instead.

## Residual risk

- **Write-scope is advisory, not enforced.** A markdown command cannot mechanically block a
  redirected MCP write, so the "only write to the configured Notion page" guarantee rests on the
  in-prompt invariant plus the injection-guard hook (which warns, does not block). A crafted source
  that names another Notion page in benign phrasing is the realistic attack. Reduced, not
  eliminated. A future hard control would need tool-layer scoping the plugin does not have today.
- **Behavioral QA is unrun.** The deterministic core (window helper) is unit-tested. Extraction,
  tiering, carry-forward, and injection resistance are model behavior over live connectors and
  cannot be exercised in this session without the user's authenticated connectors and a real Notion
  page. They need the user's one-time `--dry-run` acceptance pass (below).

## Acceptance test the user must run once

1. Add a `sweep` block to the target project's `.polaris/config.json` (the command prints the
   template if it is missing).
2. Update the installed Polaris plugin to 1.5.0 — the repo runs from a cached install, so `/sweep`
   is not live until the plugin is updated.
3. Run `/sweep --dry-run` and confirm: the window line is sensible; every list appears with both
   tiers; a known buried signal (an unassigned commitment in a recent transcript) shows under "worth
   a glance"; nothing is written to Notion or state.
4. Then run `/sweep` for real and confirm exactly one dated subpage appears under the parent.

## Not applicable

No PR (main-only convention). No deploy or runtime observability (a markdown command). Spend
telemetry not enabled, so no figure recorded.
