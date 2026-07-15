# What Polaris should build next

Date: 2026-07-15
Author: research mode (`/research`)

## The question and the decision it feeds

The open question is "what next", with no topic set. The decision it feeds is where the next
unit of build effort goes on a system that its own master plan marks feature-complete: all ten
subsystems (A through J) listed as built and shipped in 1.0.0, now at v1.2.1. So a good answer
does not hunt for a missing subsystem. It names concrete gaps between what the repo claims and
what it actually does, ranks the fixes by value against effort, and keeps verified facts apart
from my inference.

A prior report from earlier the same day (`.polaris/reports/2026-07-15-research-what-to-build-next-report.md`)
proposed seven items. The git log shows four of its top recommendations were then built, so this
report starts by confirming that and moves to what is still open, plus one gap the prior report
missed that I now rank first.

## What changed since the prior report (verified)

Four of the prior report's proposals shipped, confirmed in `git log`:

- CI plus broadened validators: `.github/workflows/ci.yml` runs `tests/run-tests.sh` on push and
  pull request; `scripts/check-commands.sh` now checks dispatched-agent references across all
  commands and every agent's `skills:` frontmatter (commit `ac7c2f1`).
- Infer-first for code-writing agents: commit `13c35a6`.
- Gate extended to Python, Go, and Rust, plus a hardened injection screen: `rules/patterns.json`
  now carries `code.py`, `code.go`, `code.rust` rule blocks, and `injection.phrases` is eight
  regex alternations covering paraphrases, not a nine-string literal denylist. A
  `tests/fixtures/injection-paraphrase.txt` fixture proves a non-literal payload is still caught
  (commit `13dd453`).
- Guardrails documentation corrected to match the code (commit `873d34c`).

After those, a daily-journal feature landed (`/journal`, a session-start next-day lookback, and
`scripts/journal-facts.sh`), unit-tested at the extractor level.

So the prior report's items 1, 2, 3, and 5 are done. Items 4, 6, and 7 remain open and are
carried below. The rest of this report is grounded in the current tree.

## Findings and proposals, ranked

### 1. Auto-maintain the work tracker (top recommendation)

**Problem.** The master plan calls the work tracker "the flagship use of the memory system" and
gives it a one-line guarantee: "You never maintain it" (§8.4). The plan specifies how it stays
current without the user: a `UserPromptSubmit` hook files each prompt into a stream, a
`PostToolUse` hook attaches touched files, a `Stop` hook records progress and the next step, and
a `SessionEnd` hook snapshots open threads. None of those exist. `hooks/hooks.json` wires exactly
four events: `SessionStart` (surfaces streams, read-only), `UserPromptSubmit` (enhance-prompt
only), `PreToolUse` (commit guard), and `PostToolUse` (guard-edit and guard-input). There is no
`Stop` hook and no `SessionEnd` hook at all.

What shipped as "the tracker" (CHANGELOG 0.8.0) is the read path and the manual write path: a
`templates/work-streams.md`, a `/track` command the user must invoke by hand, and session-start
surfacing. The auto-write path, the part that makes the promise true, was never built.

**The evidence that manual upkeep fails.** `.polaris/work/streams.md` is stale. It reads "Plugin
at v0.8.0. Building the work tracker" and lists "next: finish the work-tracker MVP, then F, then
H, then M6", while the plugin is at v1.2.1 and F, H, and the modes all shipped. The tracker rotted
because `/track` only runs when someone remembers to run it, which is the exact failure the
flagship guarantee exists to prevent. The tracker meant to stop threads from being lost is itself
a lost thread.

**Reasoning.** This is the highest-value gap because it is the plan's headline daily-pain feature
and it is broken by omission, not by a hard problem. The just-shipped journal feature already
proves the pattern that fixes it: a deterministic hook writes facts that always survive, then a
background agent enriches them without blocking the session. `journal-facts.sh` already extracts
the raw material a session snapshot needs (per-project prompts asked, commits, files changed from
the transcripts and git). The lazy, reliable shape is to reconcile at session end rather than
classify every prompt live: add a `SessionEnd` (or `Stop`) hook that writes a deterministic
session snapshot, and inject a directive for a background agent to reconcile it into `streams.md`,
the same two-step the journal uses. This sidesteps the plan's own open risk (§14: "auto-classification
accuracy", how reliably a single prompt attaches to the right stream) by reconciling a whole
session's work at once, when the file set and commits are known, instead of guessing per prompt.

**Evidence.** `hooks/hooks.json` (no `Stop`/`SessionEnd`); master plan §8.4 (the promised hooks
and the guarantee); `commands/track.md` (manual invoke); the stale `.polaris/work/streams.md`;
`scripts/journal-facts.sh` and `hooks/session-start` lines 143 to 176 (the proven hook-plus-background
pattern to reuse).

**Effort.** M. One new hook script plus a wiring entry in `hooks.json`, reusing the journal's
extraction and background-enrichment pattern. **Confidence:** high on the gap; medium on the exact
reconcile shape, because auto-classification accuracy is a real open risk the session-end approach
reduces rather than removes.

### 2. Run `/docs-drift` on the master plan and refresh the stale tracker

**Problem.** The master plan §3 table still marks subsystems E through J "Built" and states "All
subsystems shipped in the 1.0.0 release", while several concrete pieces it promises are absent:
no `monitors/` directory (§11 observability), no statusline or OpenTelemetry spend meter (§11 cost
control), no `.polaris/runs/` run history (§11, see finding 3), no `/schedule` command or routines
(§5, §10.1), no embeddings RAG memory, and no connector activation. Only the guardrails claims
were corrected (commit `873d34c`); the status table and §11 still overstate. The stale
`streams.md` from finding 1 is the same honesty gap in a different file.

**Reasoning.** Polaris ships `/docs-drift`, a mode whose whole job is finding docs that no longer
match the code. Running it on its own plan is cheap, dogfoods the tool, and keeps future "what
next" reads honest. Change the §3 status column to separate shipped from designed-but-unbuilt,
move the absent pieces into a clearly labeled "designed, not yet built" section, and while there,
correct `streams.md` to the real current state (which finding 1 would then keep current
automatically).

**Evidence.** Master plan §3 table and §11; `ls monitors` and statusline search (absent); no
`/schedule` in `commands/`; the stale `.polaris/work/streams.md`.

**Effort.** S. **Confidence:** high. (Carried from the prior report's item 4, still open.)

### 3. Write run history to `.polaris/runs/`

**Problem.** Master plan §11 states "Polaris writes its own run history to `.polaris/runs/`: which
agents ran, on which model, at what cost, with what findings and outcomes", and §11's doc-org rule
lists `runs/` as part of the enforced `.polaris/` tree. The directory does not exist and no command
or agent writes to it. The multi-agent commands that would benefit most (`/flow`, `/audit`,
`/debug`, `/incident`) leave no durable trace of what they did.

**Reasoning.** A run log is the difference between "the flow ran" and "the flow ran these agents on
these models, found these things, and here is the outcome". It is the substrate for later analysis,
for the spend meter (finding 6), and for debugging a flow that went wrong. The lazy version is a
single markdown file per run under `.polaris/runs/<date>-<command>.md`, appended by the orchestrating
commands, not a new subsystem. Scope it to `/flow` first, where the value is highest.

**Evidence.** Master plan §11 (run history, doc-org tree); `.polaris/runs/` absent; no reference to
`runs/` in `commands/` or `agents/`.

**Effort.** M. **Confidence:** high on the gap; medium on the exact format.

### 4. Cover the journal hook and `/journal` path with a test

**Problem.** The journal's extractor (`journal-facts.sh`) is unit-tested against a fixture, but the
two parts that carry the most logic are not: the session-start rollover detector (marker seeding on
first run, the `marker+1 .. today-1` range, the `mkdir` concurrency lock) and the `/journal`
regenerate path. A regression in the rollover math, for example backfilling all history on a cold
start, which the spec explicitly forbids, would pass CI today.

**Reasoning.** This is the feature the maintainer built most recently, so it is the most likely to
change next, and its riskiest logic is the untested part. A small shell test that drives the
session-start journal function with a seeded and an unseeded marker, asserting it seeds to yesterday
and does not backfill, closes the highest-risk hole cheaply.

**Evidence.** `tests/run-tests.sh` (tests `journal-facts.sh` only); `hooks/session-start` lines 143
to 170 (`polaris_journal`, untested); `docs/specs/2026-07-15-daily-journal.md` (first-run must not
backfill).

**Effort.** S to M. **Confidence:** high.

### 5. Connector activation and embeddings-backed memory (blocked, defer)

**Problem.** Two subsystem-E pieces are designed but explicitly deferred: connector activation
(Jira, Slack, analytics through MCP), which `/catchup` is "wired protocol-ready" for but cannot
use, and embeddings-backed RAG memory, which the plan says "needs a backend". Both are real
capability, and both are blocked on an external dependency: connector auth (hard in headless and
routine runs, per §14) and an embedding store.

**Reasoning.** These are the largest remaining capability adds, but they are correctly last for
now. Connectors carry no demand signal for a solo project on `main`, and the file-based memory plus
the new journal already cover the daily "what was I doing" need that RAG would serve. Doing nothing
here is defensible until there is a second user or a felt retrieval-scale problem. Build the auto
tracker (finding 1) first, because it delivers the memory system's flagship value with no external
dependency.

**Evidence.** Master plan §3 (E row: "embeddings RAG deferred"), §8.2, §14; `commands/catchup.md`
(connectors wired protocol-ready, not active).

**Effort.** L each. **Confidence:** medium on the deferral being right, high on both being absent.

### 6. Statusline spend meter (lowest priority)

Carried unchanged from the prior report. Plan §11 scopes a live cost meter reading OpenTelemetry
`claude_code.cost.usage` into a statusline. It needs OTel wiring plus a statusline script plus a
watch loop (L effort) for uncertain payoff at one user. Defer until the Opus-heavy fleet is run at
enough scale that spend is a felt problem. Finding 3's run log is the cheaper first step toward the
same visibility. Doing nothing is the right call today.

**Evidence.** Master plan §11; no statusline script in the repo. **Effort.** L. **Confidence:**
medium.

## Ranking summary

| # | Proposal | Effort | Value | Confidence |
|---|---|---|---|---|
| 1 | Auto-maintain the work tracker (SessionEnd hook + background reconcile) | M | High | High gap / med shape |
| 2 | Docs-drift the "all Built" plan + refresh stale streams.md | S | Medium | High |
| 3 | Write run history to `.polaris/runs/` | M | Medium | High gap / med format |
| 4 | Test the journal rollover and `/journal` path | S–M | Medium | High |
| 5 | Connectors + embeddings memory (blocked) | L | High later | Medium |
| 6 | Statusline spend meter | L | Low now | Medium |

## What remains uncertain

- How reliably a session's work reconciles into the right stream (finding 1). The session-end
  approach reduces the risk the plan flags in §14 but does not remove it; a cheap user correction
  path (edit `streams.md`, or a `/track` override) should ship with it.
- Whether Claude Code's `SessionEnd` hook fires reliably enough to be the sole trigger, or whether
  a `Stop` hook per turn is the safer write point. The journal chose `SessionStart` lookback
  precisely because no always-on process is guaranteed; finding 1 should reuse that lesson and not
  depend on a single end-of-session event firing.
- The right format and scope for the run log (finding 3): per-command file versus one appended
  ledger, and whether cost belongs there now or waits for OTel.

## Evidence versus inference

Evidence: the missing `Stop`/`SessionEnd` hooks, the stale `streams.md`, the absent `monitors/`,
`.polaris/runs/`, `/schedule`, and statusline, and the shipped CI, multi-language gate, and hardened
injection screen are all read directly from the tree and git log. Inference: that the auto tracker
is the highest-value next build, that reconciling at session end beats per-prompt classification,
and that connectors and RAG are correctly deferred are my conclusions from that evidence, carrying
the confidence stated per finding, not the plan's.

## Note on method

No web or connector research was needed. The question is internal, the codebase and committed plan
answer it, and the prior report already checked ecosystem prior art (SuperClaude, claude-flow, the
agentic-sdlc-plugin) and found Polaris already matches or exceeds their surface. The one thing that
would change this ranking is a stated maintainer priority that overrides value-vs-effort, for
example shipping connectors for a specific project need.
