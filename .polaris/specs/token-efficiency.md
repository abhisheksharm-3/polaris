# Token efficiency

Status: ready to build phase 1. Two open questions remain, both listed at the end with a proposed
default; neither blocks phase 1.

Input: `.polaris/specs/token-efficiency-briefing.md`, including its measured-baseline section. Every
cost figure below comes from there or from a file read in this repo.

Scope: `hooks/session-start`, `hooks/enhance-prompt`, `hooks/advance-flow`, `.polaris/work/streams.md`
handling, `workflows/review.js`, `rules/model-floor.json`, `rules/model-routing.md`,
`hooks/guard-phase`, `tests/run-tests.sh`, and one new deterministic script.

## The problem

The measured 7-day baseline reorders the work. These are independent characteristics, not a
breakdown, so they overlap and do not sum:

| characteristic | share |
|---|---|
| requests at over 150k context | 67% |
| subagent-heavy sessions | 42% |
| plugin `polaris` overall | 21% |
| four or more parallel sessions on one limit | 18% |
| `polaris:review` specifically | 6% |

Long context is the dominant term. Every request carries the whole conversation, so a long session
pays for its history on every turn even at the cached rate. Polaris's `feature` flow runs spec,
design, build, and ship as one continuous conversation, which is the shape that grows that history
fastest, and the run ledger that would let a user cut it is never recommended to them.

The review fan-out is real and worth fixing: one `/polaris:review` costs about half a session limit,
because the default level is `high`, which is 7 reviewers at `effort: 'high'` plus up to 7 verifiers,
12 of the 14 floored at opus. It is also 6% of the week. It follows the long-context work rather than
leading it.

Who has the problem: anyone running a multi-phase flow in one session, which is the intended use of
`/polaris:flow`.

The 18% from parallel sessions is behavioral rather than a defect and is out of scope; no hook, no
agent, and no criterion here polices it.

## Requirements

### R1 — a flow stops carrying its own history

At an approval stop, the conversation that produced the artifact has no further value: the artifact,
its hash, its evidence, and the phase record are on disk. `hooks/advance-flow` already fires at
`Stop` and already names what the run owes. It must also recommend a `/clear` at the point where
clearing is safe, and the recovery path must be good enough that clearing loses nothing.

What the code says about surviving a `/clear`, verified in this repo before writing the criteria:

- The ledger is on disk and keyed by project, not by session. `scripts/run-state.sh:16` reads the
  open slug from `.polaris/runs/.open`, and `state.json` holds `slug`, `flow`, `current`, and a
  `record` entry per done phase with `artifact`, `sha256`, `evidence`, and `approvedAt`. Nothing in
  that file references a session or a conversation.
- Recovery lands on the first prompt after the clear, not at session start. `hooks/session-start`
  contains no reference to `run-state`, `slug`, or `current`. `hooks/enhance-prompt:34` calls
  `run-state.sh get` on every `UserPromptSubmit` and, with a run open, injects the run, the flow, and
  the current phase, telling the session to treat the prompt as input to that run.
- One gap, and it is the reason R1 is not only a recommendation: the line at `hooks/enhance-prompt:41`
  names the phase but no artifact path. A cleared session learns it is on `design` and does not learn
  where the approved spec is. It would go looking, or guess.
- A second gap: `hooks/advance-flow:58` claims its transition with a marker keyed by session, slug,
  phase, and status. If a `/clear` keeps the session id, the marker for that phase is already claimed
  and the hook stays silent, so the recommendation cannot double as the resume announcement. Recovery
  has to come from `enhance-prompt`, which fires on the prompt regardless.

So a run does survive a `/clear` today, and the state that survives is the ledger plus the artifacts.
What is lost is the conversation, which is the point. R1 closes the artifact-path gap first, then adds
the recommendation.

The trade this makes, stated rather than hidden: `hooks/hooks.json:5` matches `startup|clear|compact`,
so every `/clear` re-pays the whole `session-start` payload, measured at 44767 bytes plus the stack
overlay. Clearing trades that re-injection against carrying a conversation that the data puts over
150k context two times in three. The trade is favorable and it is not free, which is why R2 shrinks
the payload the clear re-pays.

### R2 — the always-injected payload holds only what the first action needs

`hooks/session-start` concatenates 44767 bytes before the first prompt:

| file | bytes |
|---|---|
| `rules/core.md` | 10135 |
| `.polaris/work/streams.md` | 8872 |
| `rules/writing.md` | 5582 |
| `rules/memory.md` | 5212 |
| `rules/routing.md` | 4725 |
| `~/.claude/polaris-memory/INDEX.md` | 3978 |
| `rules/craft.md` | 3538 |
| `rules/doc-organization.md` | 1588 |
| `rules/model-routing.md` | 1137 |

The rule that decides what stays: an always-injected file must be needed by the first action of a
typical session. Anything needed only under a condition moves to a skill or a command that loads it
when the condition holds, which is what the Claude Code documentation recommends for
conditionally-needed instructions.

Three files fail that test as read:

- `rules/routing.md` describes classification that `scripts/route-prompt.sh` already performs in
  shell, and `CLAUDE.md` Rule 5 says code answers a routing question rather than a model.
- `rules/memory.md` matters when something is being saved to memory.
- `rules/doc-organization.md` matters when a doc is being written.

`.polaris/work/streams.md` fails a different test: it is injected whole and grows without bound as
streams accumulate. Only active and blocked streams belong in the payload; the Done archive is history
a session almost never reads.

Excluding the archive is not enough, and the first build of R2 proved it. Measured across six commits
the file went 1024, 1582, 3029, 3626, 7363, 17374 bytes, passing `rules/core.md` at 10135 to become
the largest single contribution to the payload. The split at the time was 192 lines above `## Done`
against 24 below, so removing the archive removed about a ninth of a file that had doubled twice. The
part that grows is the active section, which is exactly the part the archive rule keeps.

So the tracker takes a byte ceiling rather than a section filter. The injected slice holds whole
streams ordered by their `touched:` date, newest first, until 10240 bytes. What did not fit is named
by count so a session knows to open the file, because a stream dropped in silence is the one thing
the tracker exists to prevent.

The ceiling is not absolute: the newest stream is kept even when it alone exceeds it, because
emitting nothing is worse than emitting one stream over budget. This bounds the count, not a single
runaway stream, and a stream large enough to breach 10240 bytes on its own is a tracker-hygiene
problem rather than a payload one.

No byte target is set for the payload as a whole, because none has been justified. The measurement is
required and the rule above decides the content.

### R3 — the review level comes from the diff

The workflow picks the level from the changeset. `args.level` overrides the pick and is the only way
to reach `critical`.

Level from the diff, where `lines` is added plus deleted and `files` is paths touched:

| condition, first match wins | level |
|---|---|
| no changed files | none, nothing is dispatched |
| any path matches a risk pattern | `high` |
| every path matches a low-risk pattern | `low` |
| `lines` ≤ 40 and `files` ≤ 3 | `low` |
| `lines` ≤ 400 and `files` ≤ 15 | `mid` |
| anything larger | `high` |

Risk patterns: `**/migrations/**`, `**/auth/**`, `**/payment*/**`, `**/billing/**`, any of
`package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `requirements.txt`, `go.mod`,
`Gemfile.lock`, `Cargo.lock`, `Dockerfile`, `.github/workflows/**`, `**/*.tf`, plus any path holding
`secret`, `crypt`, or `token` in a filename.

Low-risk patterns: `*.md`, `docs/**`, `tests/**`, `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`.

Auto-selection never returns `critical`. `critical` differs from `high` only in confirm depth, so a
human asks for it; no threshold guesses it.

These numbers are the part of this spec most likely to need tuning. They are a starting point chosen
so a typical single-slice commit lands on `low` or `mid` and a multi-file feature lands on `high`.
They live in one table in one place, and prose elsewhere defers to it.

### R4 — the model floor and the effort floor both follow the level

`rules/model-floor.json` gains a review floor per level: sonnet at `low` and `mid`, opus at `high` and
`critical`. It applies to `reviewer`, `security-architect`, `tester`, `verifier`, and `ux` when they
are dispatched by `workflow:review`. Outside a review level, the existing per-agent floor stands
unchanged. `rules/model-routing.md` states the exception, because today it pins review to opus with no
qualifier and a reader would call the sonnet dispatch a violation.

The tier lever saves only on per-token price. A fan-out gives each subagent its own cache regardless
of tier, so mixing tiers is cache-neutral and none of the fixed per-agent cost goes away. If it costs
any measurable quality, it is dropped rather than tuned: the agent-count work in R3 is where the
review saving actually lives.

Reasoning effort is the other half of this requirement, and on the docs' own numbers it is the larger
half. Thinking tokens bill as **output**, and the default budget runs to tens of thousands of tokens
per request, so effort moves the output side of a dispatch the way the tier moves its per-token
price. An audit found effort governed almost nowhere:

- `workflows/review.js` set it for reviewers from the `LEVELS` table and omitted it on the Confirm
  dispatch, so up to seven verifiers ignored the level entirely and took the session's setting.
- `workflows/verify.js` hardcoded `high` for every angle of every round, and rounds multiply the
  fan-out.
- `workflows/build.js` hardcoded `high` on three of its five dispatches and set nothing on the other
  two.
- `rules/model-floor.json` and `rules/model-routing.md` govern tier alone, so nothing enforced effort
  at dispatch the way `hooks/guard-phase` enforces the model floor.

So effort becomes a first-class column wherever tier is already governed:

- `rules/effort-floor.json` mirrors `rules/model-floor.json`: a minimum reasoning effort per agent,
  over the same agent set, with judgment and adversarial work at `high`, implementation at `medium`,
  and the mechanical agents at `low`. The two files must name the same agents, or one silently
  protects a subset of the other.
- `hooks/guard-phase` enforces it the way it enforces the tier: a dispatch below an agent's floor is
  refused with a reason naming the floor, and a dispatch that names no effort is left alone, because
  the session's setting is the policy there.
- Every dispatch in every workflow names an effort drawn from that workflow's level table. A dispatch
  that omits it inherits the session's setting, which is how two workflows came to run every agent at
  `high` with nothing recording the decision.
- `workflows/verify.js` binds effort and its round ceiling to one level, because rounds multiply the
  fan-out and governing effort without governing rounds governs a fraction of the cost.

Unlike the tier lever, this one is not dropped if quality moves; it is retuned per level, because
effort is the dial the level concept exists to turn.

### R5 — the evidence is packed once

Every reviewer receives the same evidence pack in its prompt: the numstat and the unified diff,
truncated at 1500 diff lines with a line saying it was truncated and how many lines were dropped. The
reviewer prompt states that the pack is the evidence and that reading files is for what the pack does
not answer.

The pack is a value built once inside the workflow, not a dispatch. The non-goal below forbids a new
agent, and this requirement adds none.

### R6 — confirm only what changes an action

At `high`, a `medium` finding is confirmed only when its `fix` field is longer than 80 characters,
which is the proxy for a fix large enough that a wrong verdict costs real work. Shorter fixes are
returned in `unconfirmed` with `why` naming the reason. `high` severity is always confirmed, at every
level that confirms anything. `critical` is unchanged.

### R7 — the evidence is agent count and tier, not a session figure

A report at `.polaris/reports/<date>-token-efficiency.md` holds:

- The 7-day `/usage` baseline as recorded above, with the date it was read.
- The `session-start` payload measured per file, before and after R2.
- Agent count and model tier per agent for the same review target at each level, read from the
  workflow's own dispatch labels.
- The quality check: the reduced configuration run against a target with known high-severity findings,
  with a hit or miss per finding.

`/usage` reports over 24-hour and 7-day windows and attributes by behavior, not per run, so a per-run
before-and-after session figure is polluted by whatever else ran in that session. Where a session
figure is used at all, it comes from a session that ran only the review target and nothing else, and
the report says so on the line that carries it.

## Phasing

Phase 1: R1, R2, R7. The 67% term, and it touches no reviewer prompt.
Phase 2: R3, R4. The 6% term.
Phase 3: R5, R6. Both change what reviewers are told, so they are measured after phase 2's numbers are
recorded rather than mixed into them.

## Testing seams

Confirmed with the user before build:

1. `hooks/advance-flow` — a JSON payload on stdin, a block decision on stdout. R1 is testable here
   against a temporary project directory, as `tests/run-tests.sh` already does for `guard-command`.
2. `hooks/enhance-prompt` — a prompt payload on stdin, `additionalContext` on stdout.
3. `hooks/session-start` — no stdin, one JSON object on stdout. R2's payload is measured by reading the
   byte length of `additionalContext`.
4. `scripts/review-level.sh` — reads `git diff --numstat` output on stdin, writes one of `low`, `mid`,
   `high`, or an empty string on stdout. All of R3 is testable here with no dispatch and no model.
5. `workflows/review.js` read as text by the node block at `tests/run-tests.sh:745`.
6. `hooks/guard-phase` — a JSON payload on stdin, a permission decision on stdout, as at
   `tests/run-tests.sh:797`.
7. `rules/model-floor.json` read by `jq`, as at `tests/run-tests.sh:815`.

No seam crosses into an agent's internals. R7 is the one requirement checked by a human reading a file,
and it is written that way because the briefing rules out estimates.

## Acceptance criteria

Every criterion is checked by `bash tests/run-tests.sh` unless it names something else.

**AC1.** Given a run seeded and its first phase recorded and approved, when `state.json` is read with
no session and no conversation, then it holds `slug`, `flow`, `current` pointing at the next phase, and
a record entry with `artifact`, `sha256`, `evidence`, and `approvedAt`.

**AC2.** Given the same run and a recorded artifact whose bytes changed after recording, when
`scripts/run-state.sh assert <later-phase>` runs, then it fails and names the changed artifact. This
already holds at `scripts/run-state.sh:183` and is asserted here because R1 depends on it.

**AC3.** Given a run open on phase `design`, when `hooks/enhance-prompt` receives any non-empty prompt,
then `additionalContext` names the run slug, the flow, the current phase, and the artifact path
recorded by the most recent done phase.

**AC4.** Given no run open, when `hooks/enhance-prompt` receives a prompt, then no run line is injected
and the hook exits 0.

**AC5.** Given the current phase has `approvedAt` set and `current` has moved to the next phase, when
`hooks/advance-flow` fires, then the block reason recommends `/clear` and names both the run slug and
the artifact path the next phase reads.

**AC6.** Given the current phase's record status is not `done`, when `hooks/advance-flow` fires, then
the reason asks for the phase to be run and recorded, and contains no `/clear` recommendation.

**AC7.** Given the current phase is `done` but has no `approvedAt`, when `hooks/advance-flow` fires,
then the reason asks for the approval and contains no `/clear` recommendation.

**AC8.** Given a done phase whose recorded artifact is missing from disk, when `hooks/advance-flow`
fires, then no `/clear` is recommended. Clearing is recommended only when the state that would replace
the conversation is verified present.

**AC9.** Given two `Stop` events for the same session, slug, phase, and status, when
`hooks/advance-flow` fires twice, then it blocks at most once, which is the behavior at
`hooks/advance-flow:58` and must not change.

**AC10.** Given `hooks/session-start` runs in this repo, when the byte length of `additionalContext` is
measured, then the report at `.polaris/reports/<date>-token-efficiency.md` holds that number with a
per-file breakdown, before and after R2. Checked by a human reading the report against a recorded
command.

**AC11.** Given `hooks/session-start` after R2, when the test greps it, then it reads none of
`rules/routing.md`, `rules/memory.md`, or `rules/doc-organization.md`, and each of those three is
reachable from a skill or a command that loads it when relevant.

**AC12.** Given a `.polaris/work/streams.md` holding active, blocked, and Done sections, when
`hooks/session-start` runs, then `additionalContext` holds the active and blocked entries and holds no
line from the Done section.

**AC13.** Given a `.polaris/work/streams.md` that trips the injection check, when `hooks/session-start`
runs, then the file is withheld and the payload says so, which is the behavior already in the hook and
must survive R2.

**AC14.** Given a numstat holding `3 1 README.md`, when `scripts/review-level.sh` runs, then it prints
`low` and exits 0.

**AC15.** Given a numstat holding `2 0 src/auth/session.ts`, when the script runs, then it prints
`high`, because a risk path beats the size rule.

**AC16.** Given a numstat holding 4 files totalling 120 changed lines under `src/`, when the script
runs, then it prints `mid`.

**AC17.** Given a numstat holding 20 files totalling 900 changed lines, when the script runs, then it
prints `high`.

**AC18.** Given a numstat holding `600 400 tests/run-tests.sh`, when the script runs, then it prints
`low`, because a test-only diff drops whatever its size.

**AC19.** Given empty stdin, when the script runs, then it prints an empty string and exits 0.

**AC20.** Given a numstat holding both `db/migrations/004.sql` and `docs/api.md`, when the script runs,
then it prints `high`. Risk wins over the low-risk rule and the order of the paths does not change the
answer.

**AC21.** Given no `args.level`, when `workflows/review.js` runs against a changeset the script rates
`low`, then exactly 2 agents are dispatched and the returned object has `level: 'low'`.

**AC22.** Given `args.level` is `critical`, when the workflow runs against a one-line docs diff, then
the returned object has `level: 'critical'` and 7 reviewers are dispatched. The explicit argument beats
the diff.

**AC23.** Given `args.level` is `banana`, when the workflow runs, then the level from the diff is used
and `log` records that the argument was not recognized. An unrecognized argument no longer means
`high`.

**AC24.** Given a changeset with no changed files, when the workflow runs, then no agent is dispatched
and the returned object says so.

**AC25.** Given `rules/model-floor.json`, when the test reads it, then it holds a review floor map
whose keys are exactly `low`, `mid`, `high`, `critical` with values `sonnet`, `sonnet`, `opus`, `opus`,
and every per-agent floor still names a file in `agents/`.

**AC26.** Given a dispatch payload for `reviewer` at model `sonnet` carrying the review level `mid`,
when `hooks/guard-phase` reads it, then it emits nothing.

**AC27.** Given the same payload carrying the review level `high`, when `guard-phase` reads it, then it
emits `"permissionDecision":"deny"` and the reason names `opus`.

**AC28.** Given a dispatch payload for `reviewer` at model `sonnet` with no review level at all, when
`guard-phase` reads it, then it emits a deny naming `opus`. The exception is scoped to a review level
and does not open the floor generally.

**AC29.** Given `rules/model-routing.md`, when the test greps it, then it names the review level
exception and points at `rules/model-floor.json`.

**AC30.** Given `workflows/review.js`, when the test reads it, then `over-engineering` appears in every
level's key list, which is the assertion already at `tests/run-tests.sh:745`.

**AC31.** Given `workflows/review.js` after phase 3, when the test reads it, then one evidence pack
value is built before the reviewer fan-out and every reviewer prompt interpolates it.

**AC32.** Given a diff of 4000 lines, when the pack is built, then the pack holds at most 1500 diff
lines and a line stating how many were dropped.

**AC33.** Given a `medium` finding at `high` whose `fix` is 30 characters, when the workflow runs, then
no verifier is dispatched for it and the finding is returned in `unconfirmed` with `why` naming the fix
size.

**AC34.** Given a `high` severity finding at `mid`, when the workflow runs, then a verifier is
dispatched for it. Narrowing never reaches high severity.

**AC35.** Given the report at `.polaris/reports/<date>-token-efficiency.md`, when a reviewer reads it,
then it holds the dated 7-day baseline, the payload measurement per AC10, and agent count with tier per
agent for each level. Any session figure in it names the clean session it came from.

**AC36.** Given a review target with a recorded list of high-severity findings, when the reduced
configuration runs against it, then every finding on that list appears in the output. A run that saves
tokens and loses one high-severity finding fails, and the configuration is rejected whatever it saved.

### Added 2026-08-09, with R2's ceiling and R4's effort half

**AC37.** Given `rules/effort-floor.json`, when its agent keys are compared with those of
`rules/model-floor.json`, then the two sets are identical. Checked by `diff` over both key lists in
`tests/run-tests.sh`.

**AC38.** Given a dispatch of an agent at an effort below its floor, when `hooks/guard-phase` reads
it, then the dispatch is denied and the reason names the required floor. Checked with a `reviewer`
dispatch at `low`.

**AC39.** Given a dispatch at or above an agent's effort floor, or one naming no effort at all, when
`hooks/guard-phase` reads it, then the dispatch is allowed. The no-effort case matters most: the
session's setting is the policy there, and refusing those would break every existing call site.

**AC40.** Given any file in `workflows/`, when its `agent(` dispatch count is compared with its
`effort:` count, then effort is named at least as often as an agent is dispatched. This is the
assertion that would have caught the omitted verifier effort in `review.js`.

**AC41.** Given a tracker whose streams total more than the ceiling, when `scripts/tracker-slice.sh`
runs at 10240 bytes, then the output is within the ceiling, holds fewer streams than the file, orders
them newest `touched:` first, and names how many were dropped. Four separate checks, because a slice
that silently drops a stream is worse than one that injects too much.

**AC42.** Given a tracker with CRLF line endings, when the slice runs, then the `## Done` archive is
still withheld. A `## Done\r` line does not match `^## Done$`, which is how a section filter stops
working without anyone noticing.

**AC43.** Given a tracker file that exists but cannot be read, when the slice runs, then it exits 0
and `hooks/session-start` still emits its payload. `session-start` runs under `set -euo pipefail`, so
an unreadable tracker previously cost the entire session's context rather than one section of it.

**AC44.** Given `hooks/hooks.json`, when the suite reads it, then it registers no `type: "prompt"`
hook on `UserPromptSubmit`. The clarity veto was removed during this run after it false-stopped three
real prompts; it is recorded here because a change enforced by the suite belongs in the spec, and
because `hooks/hooks.json` must therefore be committed with `tests/run-tests.sh` rather than after it.

## Persona findings

**Ideal customer.** Runs `/polaris:flow` on a feature, approves the spec, sees the `/clear`
recommendation with the spec's path in it, clears, and types the next prompt. `enhance-prompt` names the
run, the phase, and the artifact, and design starts on a short context. Review later picks `mid` from a
3-file diff and dispatches 4 sonnet reviewers.

**Naive user.** Clears without approving. AC6 and AC7 mean no recommendation was made there, and
`enhance-prompt` still names the run and the phase on the next prompt, so the work is re-presented
rather than lost. Passes `level: high` on a typo fix and pays for 7 reviewers, which is a legitimate
override. Passes `level: banana` and gets the diff's level with a log line.

**Power user.** Runs a 40-file refactor review: the size rule says `high` and the cost is the cost, with
the saving coming from R5 and R6. Runs two flows in two terminals on one project: the ledger allows one
open run per project by design at `scripts/run-state.sh:73`, so the second is refused rather than
silently interleaved.

**Attacker.** A branch adds `src/utils/token-helper.ts` in an otherwise trivial diff, and the filename
rule escalates to `high`, so a path chosen to look harmless does not buy a cheaper review of a
credential path. A hostile finding summary reaching a verifier is already fenced as untrusted data at
`workflows/review.js:113`, and R6 shrinks how many findings reach a verifier without loosening that
fence. `.polaris/work/streams.md` is project-controlled, so the injection screen in front of it stays in
place under R2, per AC13. The review level in a dispatch payload is a trust boundary: whatever field
carries it must be written by the workflow, never copied from a prompt or a finding.

## Edge cases and error states

- No run open and `advance-flow` fires: silent, as today at `hooks/advance-flow:35`.
- `jq` absent: every hook here exits 0 and injects nothing. Failing open on cost never fails closed on
  work.
- `.polaris/config.json` has `"routing": false`: no run line, no recommendation, no level seeding.
- `git diff --numstat` fails or git is absent: the script prints an empty string, and the workflow falls
  back to `high`. Failing open on cost is safer than failing open on quality.
- A numstat line with `-` in place of a count, which git emits for a binary file: 0 lines and 1 file, and
  the path still runs against the risk patterns.
- A renamed path in numstat arrow form: both sides run against the risk patterns.
- `args.level` present but not a string: treated as absent.
- A reviewer returns no findings: no verifier for that dimension, as at `workflows/review.js:106`.
- A verifier returns fewer verdicts than claims: the uncovered findings stay `unconfirmed` with
  `why: 'no verdict returned'`, as at `workflows/review.js:134`.
- The evidence pack exceeds the truncation cap: AC32. The dropped-line count is stated so a reviewer
  knows the pack is partial rather than assuming it is whole.

## Non-goals

- No change to what the `over-engineering` dimension is or to its mandatory status. Every level keeps
  it, and `hooks/guard-review` deadlocks without it.
- No new agent and no new hook. The saving comes from dispatching fewer and cheaper agents and from
  carrying less context, not from new machinery. A deterministic script is neither.
- Nothing that polices parallel sessions.
- No change to `rules/flows.json`.
- No forced `/clear`. The hook recommends and the human decides.
- No new agent and no new hook. A deterministic script is neither.

Withdrawn on 2026-08-09, by the user, after the effort audit: this spec previously ruled out any
change to `verify.js` and `build.js`, on the argument that whether the level concept transfers was a
design-phase question. The audit answered it. Both files hardcoded `high` or set nothing, so leaving
them alone would have governed effort in one workflow of three. R4 now covers all three.

## Success metrics

- Share of requests over 150k context: 67% today. Target under 40%, read from `/usage` at 7 days, after
  the flow has been run with the recommendation in place.
- The `session-start` payload: 44923 bytes at the start of this run, 29777 after R1, R2 and the
  tracker ceiling, each measured by the byte length of the emitted `additionalContext`. No target; the
  rules in R2 decide the content and AC10 records the number.
- The injected tracker slice: 15460 bytes above `## Done` before the ceiling, 8660 after. The ceiling
  itself is the metric that matters, since the file had doubled twice before anything bounded it.
- Default-path review agent count on a median diff: 14 today, target 4 or fewer, read from the
  workflow's dispatch labels.
- Workflow dispatches naming an explicit effort: 6 of 12 before the audit, all 12 after.
- High-severity findings retained: 100%, per AC36. Any loss fails the change.

## Open questions

1. **Which payload field carries the review level to `guard-phase`.** The hook reads stdin JSON and
   cannot see the workflow's `label`. Proposed default: the workflow writes the level into the dispatch
   `description` and `guard-phase` reads `tool_input.description` for a `level:<name>` token. Risk of
   guessing wrong: if the field does not reach the hook, AC26 fails and the sonnet reviewers are refused
   at dispatch, which is loud rather than silent.
2. **Whether `workflows/review.js` can run a shell command.** R3 needs the numstat, and no workflow in
   the repo runs one. Proposed default: the caller runs `scripts/review-level.sh` and passes the result
   as `args.level`, which keeps AC14 through AC20 testable either way and moves only AC21's wiring.
   Resolve it in the design phase by reading the workflow runtime, not by guessing.
