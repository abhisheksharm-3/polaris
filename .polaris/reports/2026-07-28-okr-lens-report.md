# Report — OKR lens on `/sweep`

**Date:** 2026-07-28   **Commits:** 84d4717..2a34d79 on `main`

## What was built

A mode that turns the twice-daily `/sweep` the user already runs into an OKR coach, gated entirely on
the presence of `.polaris/okr/ledger.md`. Absent that file, `/sweep` is unchanged.

- **`scripts/okr-pace.sh`** — a deterministic helper (bash + jq) that reports each KR's pace as
  `behind` / `on-track` / `ahead`, or `flag` with `done` for non-numeric KRs. `behind` carries
  `needToCatch`, the units needed to get back on pace. Mirrors `sweep-window.sh`. Five tests in
  `tests/run-tests.sh`.
- **Morning** (in the `/sweep` morning run): an "OKR — today" section listing the behind KRs and two
  or three moves for today, placed against calendar blocks matched to KRs by title and description. A
  match suggests a block; it never advances a KR.
- **Evening** (in the `/sweep` evening run): a three-question interview (what moved, which KR,
  evidence link) that is the only thing that advances a KR. Writes to `.polaris/okr/log.md` and
  `progress.json` after the Notion write.
- **`/sweep --okr-review`**: fills the Score Log and tracker tables from the log, on partial data,
  to `.polaris/reports/okr-review-<date>.md`.
- **Templates**: `templates/okr-ledger.md` and `templates/okr-progress.json` to seed once.

## What was found and fixed

- **The idea's original framing was wrong and got corrected before any code.** "Feed once, get a
  perfect rating" cannot work: no connector produces the outcomes, and the scoring legend punishes
  gaming. The design that survived is honest tracking, not autopilot.
- **A near-duplicate was avoided.** `/sweep` already owns the twice-daily connector pull. The lens
  rides on it instead of rebuilding it, and the evening interview is a second ritual avoided.
- **TDD caught a bad test assertion of mine.** A KR at 3 of 6 on day 2 of the period is ahead, not
  on-track; the fix was to the test's expectation, not to loosen the helper's threshold.

## What is accepted, with rationale

- **The `check-commands.sh` OKR-file-naming check from the spec's testing section was dropped.** It
  would bolt a bespoke grep onto a single-purpose script for little gain. The helper's tests and the
  writing gate are the real guarantees.
- **Semantic calendar matching can over-match** (a "1:1 with manager" reading as OKR ownership time).
  Accepted because a match only suggests a block and never books progress, so a false match costs
  nothing but a suggestion.

## Residual risk

The command's model-driven behavior is unverified end to end. The deterministic surface is green
(helper 5/5, template parse, `check-commands.sh` 0, prose gate clean, full suite 0), but the
interactive `/sweep --dry-run` walkthrough did not run: this repo has no `sweep` block in
`.polaris/config.json` and no live connector or Notion setup. Until that walkthrough runs, the
section render, the calendar match, the evening interview, and the review render are specified and
committed but not exercised.

## Pending user acceptance step

To exercise the lens end to end, in a project that has the `sweep` connectors configured:

1. `mkdir -p .polaris/okr && cp <plugin>/templates/okr-ledger.md .polaris/okr/ledger.md && cp <plugin>/templates/okr-progress.json .polaris/okr/progress.json`, then edit both to your OKRs.
2. Run `/sweep --dry-run` on a morning clock. Confirm the "OKR — today" section lists the behind KRs
   from the helper and proposes moves, and that nothing under `.polaris/okr/` changed.
3. Run `/sweep --dry-run` on an evening clock. Confirm it prints the three questions and a would-be
   log entry and writes neither file.
4. Remove the ledger and run `/sweep --dry-run`. Confirm no OKR section appears.

## PR

Not opened. Awaiting confirmation to push and raise it.
