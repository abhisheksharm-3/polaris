# Spec — `/sweep --okr-init`

> Extends the `/sweep` OKR lens (`.polaris/specs/2026-07-28-okr-lens-spec.md`). Closes the onboarding
> gap: today a user hand-writes `progress.json`; this mode generates it and the ledger from a pasted
> or linked OKR doc, once.

## Problem

The OKR lens turns on when `.polaris/okr/ledger.md` exists, and it needs `progress.json` with each
KR's id, target, deadline, and kind. A user creates both by hand today. Hand-mapping prose KRs to
numeric targets and per-quarter deadlines is error-prone, and nothing tells an existing user the lens
exists. The user's OKR already lives as a structured doc; converting it once is the "feed once" the
lens was meant to have.

## Scope

In: one new mode on `/sweep`, `--okr-init`, added to `commands/sweep.md`. It reads an OKR doc from the
user's message or a file path, and writes `.polaris/okr/ledger.md` and `.polaris/okr/progress.json`.
No new script, no new test: the deadlines and quarter labels are read from the doc, so there is no
date math to push to a helper, and the output is validated by the existing `okr-pace.sh`.

Out: no scraping of connectors, no editing of an existing ledger, no support for OKR formats that
carry no quarterly targets or deadlines (the mode names what it could not extract rather than
guessing). Prior progress is captured by a short per-KR interview, not scraped.

## Design

`/sweep --okr-init [path]` runs as a distinct mode: it pulls no source and writes no sweep page.

1. **Get the OKR text.** From `[path]` if given, else from the user's message. If neither carries an
   OKR, stop and ask for it.
2. **Overwrite guard.** If `.polaris/okr/ledger.md` or `.polaris/okr/progress.json` already exists,
   stop and write nothing, reporting that the lens is already initialized and to delete the files (or
   edit them) rather than re-init. No silent clobber.
3. **Write the ledger.** Save the OKR prose to `.polaris/okr/ledger.md`, lightly normalized to the
   template's headings. This is the human copy the morning calendar match reads.
4. **Extract the KRs to `progress.json`.** Model extraction (Rule 5). For each KR:
   - `id` — stable, from the objective and KR numbering (`O2-KR1`); disambiguate split KRs with a
     suffix (`O4-KR2-writeups`).
   - `metric` — the KR's measure in a few words.
   - `kind` — `flag` when the KR is done-or-not (a clean launch, a signed-off area); else numeric.
   - `current` — from the backfill interview in step 5, not guessed.
   - `target` and `deadline` — **the current period's values, read from the doc** (see below).
   - `committed` — from the KR's committed/aspirational label.
5. **Backfill interview.** Before writing `progress.json`, ask the user, per KR, how much is already
   done: "how many `<metric>` so far?" for a numeric KR (empty answer means 0), and "is `<metric>`
   done? (y/n)" for a flag KR (yes sets `current` to its target, no to 0). Present them as one
   compact list the user can answer in a single reply, not one prompt at a time.
6. **Validate.** Run `okr-pace.sh --now <now> --progress .polaris/okr/progress.json`. If it errors,
   report the malformed entry and stop rather than leave a broken file.
7. **Report.** Name the file paths written and list every KR with its extracted target, deadline, and
   the `current` the user gave, plus anything that could not be extracted.

### Period modeling (the one real decision)

OKRs with cumulative quarterly targets (this user's O2 is 3 / 6 / 9 / 12 across Q1–Q4) must be paced
against the quarter the user is in, not the annual number. The rule:

- Determine the current quarter from `now` against the doc's own quarter labels (the doc names them,
  e.g. "Q2 Tracker (Jul - Sep 2026)").
- `target` = that quarter's cumulative value for the KR (6, not 12).
- `deadline` = that quarter's end date, read from the doc's quarter label (2026-09-30).
- `periodStart` (one value for the file) = the cycle start read from the doc (2026-04-01), so pace is
  measured from the cycle start toward the current quarter's cumulative target.

A KR whose target **repeats each quarter** rather than accumulating (for example 2 writeups every
quarter) uses the **annual total** as `target` and the cycle-end deadline, so it paces linearly across
the year from the single `periodStart` instead of reading as behind early in each quarter. A KR with a
single annual target and no quarterly breakdown uses that target and the cycle-end deadline. A KR the
doc gives no number for is emitted as `kind: flag` if it reads as done-or-not, or named in the report
as un-extractable if it is neither countable nor a flag.

## Acceptance criteria

```
Given no .polaris/okr/ files exist and the user pastes their FY 2026-27 OKR with now = 2026-07-28
When /sweep --okr-init runs
Then .polaris/okr/ledger.md holds the OKR prose
And the mode asks, per KR, how much is already done
And progress.json has O2-KR1 with target 6, deadline 2026-09-30, periodStart 2026-04-01, and the
  current the user gave (0 if the answer was empty)
And okr-pace.sh accepts progress.json without error
```

```
Given a KR labeled done-or-not with no count (a clean production launch)
When /sweep --okr-init runs
Then its entry has "kind": "flag" and is not given a numeric target
```

```
Given .polaris/okr/ledger.md already exists
When /sweep --okr-init runs
Then it writes nothing and reports the lens is already initialized
```

```
Given /sweep --okr-init runs with no OKR text in the message and no path
Then it stops and asks for the OKR doc, writing nothing
```

```
Given the finished command additions
Then every line passes the writing standard (rules/writing.md)
```

## Assumptions for the approval gate

1. **Current values come from a per-KR backfill interview** (empty answer means 0). Chosen by the
   user over a 0-default, so a mid-cycle user starts accurate without hand-editing. Risk: the
   interview asks one question per KR; mitigated by presenting them as a single compact list.
2. **Period = current quarter's cumulative target, paced from cycle start.** The core modeling call.
   Risk: a KR with front- or back-loaded work reads as off-pace mid-quarter; the user can edit any
   deadline after. Confirm.
3. **Overwrite refused, not merged.** Re-init requires deleting the files. Risk: low; protects hand
   edits. Confirm.
4. **OKR text from the message or a path argument.** Risk: low. Confirm.
5. **No new script or automated test; validation is `okr-pace.sh` on the output.** The extraction is
   model judgment and not unit-testable; the guarantee is that the produced file passes the helper.
   Confirm this is enough.
