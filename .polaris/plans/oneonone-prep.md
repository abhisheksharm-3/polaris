# 1:1 preparation mode implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox
> (`- [ ]`) syntax.

**Goal:** ship `/oneonone` with three verbs (`add`, assemble, `recap`) against the 87 acceptance
criteria in `.polaris/specs/oneonone-prep.md`, reusing `sweep-window.sh`, `okr-pace.sh`,
`worktracker-snapshot.sh`, and the `/sweep` config resolution, and adding two shell scripts and one
command file.

**Architecture:** one command file, two new scripts, one changed script, four reused scripts.

- `commands/oneonone.md` holds the instructions and every judgment call. It makes the connector
  calls, ranks candidates, writes prose, and decides nothing a shell expression can decide.
- `scripts/oneonone-join.sh` owns the calendar-to-recording join: the structural 1:1 test, the
  forward bracket, the lag constant `L`, the claiming pass, and the resolved-or-ambiguous-or-empty
  verdict. It is the hardest mechanism in the spec and the one most likely to be wrong, so it is the
  one that gets fixtures and assertions.
- `scripts/oneonone-inbox.sh` owns `inbox.md`: append, list open, consume, restore. The capture path is
  otherwise reachable only through a model, which this suite cannot assert on. `restore` reopens an
  item the meeting never reached, which is the carry-forward the spec has no criterion for.
- `scripts/sweep-window.sh` gains `--first-run-hours`, defaulting to 24 so the five existing
  assertions and the one existing caller do not move.
- Reused unchanged: `scripts/okr-pace.sh` for per-KR pace, `scripts/worktracker-snapshot.sh` for
  commits and files per project since the window start, `scripts/check-commands.sh` and
  `scripts/check-patterns.sh` as gates.

**Tech stack:** bash 3.2, `jq`, `awk`, `find`. No new dependency. No new agent, no new hook, no new
workflow.

**State:** `~/.claude/polaris-memory/oneonone/` holds `state.json` (cursor, resolved recordings,
observed ingest lag, the last agenda's hash, last page), `config.json` (only a disambiguated
`recurringEventId`), `inbox.md`, and `agendas/<date>-oneonone.md`. Nothing is written into a project.

**The loop this builds** is three-legged, because that is the one the user already performs by hand:
prepare an agenda from the fortnight, hold the meeting, write the outcomes back into the same two
artifacts. The recap never creates a second record of one meeting.

---

## Reconciled against the real artifact

One full cycle has already been run by hand: the agenda at
`~/.claude/polaris-memory/oneonone/agendas/2026-08-05-oneonone.md`, the Notion page it was written to,
the meeting held 2026-08-07 as an untitled impromptu call
(the 2026-08-07 recording), and the `## Outcomes` section written back afterwards. Where
the spec and that artifact disagree, the artifact wins and the AC changes. Five disagreements.

**A1. The loop is three-legged, not two.** Prepare, meet, recap into the same artifact. The recap
writes back to the file and to the existing page, and creates neither. AC 52 already says this for the
page; the plan makes it explicit that a recap never calls `notion-create-pages` under any condition,
including a failed lookup. The local copy on disk now carries its `## Outcomes` section, so both sides
did get written; the design requires both every time, and the local one first.

**A2. AC 10's section list and order are both wrong.** The artifact's order is `Wins`,
`Top 3 they need to know`, `To discuss live`, `Forward deployment`, `Career and feedback`,
`Open from last time`, `OKR snapshot`, `Status grid`, `Outcomes`. AC 10 puts `Career and feedback`
fourth, `Status grid` fifth, `Open from last time` last, and omits `Forward deployment` and
`OKR snapshot` entirely while saying "and no other". The artifact order is the one that survived a
real meeting: the two sections the manager answers come before the two they read for reference, and the
status grid sits last because it is the part nobody reads aloud. **AC 10 changes to the artifact's
nine-section order.** Task 6 step 1 follows the artifact.

**A3. `Forward deployment` is a distinct section and it is not a second OKR table.** The user's own
correction on the generated draft: "fde section reads like mirror OKRs, and doesn't make any sense, I
want to confirm from manager how am I doing on FDE parameters." The shipped version is six numbered
questions directed at the manager, two of them marked `priority` so a short meeting still answers the
ones that matter, plus two prose subsections on participation and on whether the handover is being
used, each ending in an `Ask:`. This is content the manager answers, not a status readout, and it is
not counted against the two-question budget, which governs questions asked *of the user* at assemble
time. **New requirement, no AC covers it.** Decision D11.

**A4. AC 34 conflicts with edit preservation.** "The second run rewrites that one file" is the rule.
The user's correction is "what I removed should have stayed removed", and separately
"concierge onboarding isn't built by me, don't count it", which is a wrong attribution that the user
fixed by hand. Derived attribution is wrong by default some of the time, so the correction has to
stick, and a rule that rewrites the file on the next run destroys it. **AC 34 changes: one file per
date still, rewritten only when the user has not touched it.** Decision D9.

**A5. Carry-forward of unraised agenda items has no AC at all.** The real recap's `### Not raised`
lists seven prepared items the meeting never reached, and closes with "carry the six unraised items
into the next 1:1". Nothing in R5 covers this: AC 25, 26, 27, and 61 all carry *actions that came out
of* a meeting, and an item that was prepared and never discussed is the opposite of that. The gap is
real and it is the most common outcome of a 45-minute slot with nine sections. **New requirement, in
scope, no AC.** Decision D10.

**A6, which is not a disagreement.** The artifact's `## Outcomes` opens with "Transcription quality is
poor and Fathom did not separate speakers, so everything below is what the room agreed, not who said
it." The user shipped that hedge by hand, on a real document, to a real manager. AC 79 is validated
rather than speculative, and it strengthens D2 below.

## What I checked in the spec, and where it is wrong

Four further corrections. Each changes a task below.

**1. AC 84 makes AC 81 unreachable.** AC 84 says to drop every candidate recording carrying
`calendar_invitees`. AC 69 requires the 1:1 to exist as a calendar event with two attendees. A 1:1
held over a video call therefore produces a recording whose `calendar_invitees` are exactly those two
attendees, and AC 84 drops it. The `labeled: true` path in AC 81 can then never be reached through
the join, and the only 1:1 the mode can ever resolve is an in-person one. The observed 2026-07-22
meeting was in person, which is why the spec did not see this. Task 2 replaces the flat drop with a
ranked claim that compares invitee sets. Decision D1 below.

**2. AC 54's budget omits the delivery calls.** It counts eighteen derivation calls and stops there.
AC 48 adds a Notion create, AC 49 adds an update in place, and AC 52 adds an append on recap. A
budget that a conforming run provably exceeds is not a budget. Task 7 restates it as two budgets,
eighteen for derivation and two for delivery, which is the split A7 already draws. Decision D5.

**3. The testing seam for `check-commands.sh` is misdescribed.** The spec says it "covers the command
file's frontmatter". It does not. `scripts/check-commands.sh:14-27` checks that every backticked
lowercase token on a line containing the word "dispatch" resolves to an agent, a skill, or a command;
lines 29-58 check the `skills:` frontmatter of *agents*, not commands. Nothing validates a command's
frontmatter anywhere in this repo. The real constraint on `commands/oneonone.md` is narrow and worth
stating: it must not put a backticked lowercase token on a line containing "dispatch" unless that
token names a real agent or command. Task 4 carries it.

**4. Q6 and Q7 contradict each other, given the code.** Q7's default is one row in the `routing`
class of `rules/patterns.json`. Q6's default is no row in `rules/flows.json`. `tests/run-tests.sh`
lines 506 to 511 assert that every routing class is a key in `rules/flows.json`, so Q7 alone turns the
suite red. They are one decision, not two. Decision D4 resolves both to no.

---

## The two arguments I was asked to break

### `L` = 3 hours rests on one sample

It does, and the spec says so. What the spec does not do is make being wrong cheap. Three changes in
task 2 do:

1. **`L` is one constant with a runtime override.** `LAG_HOURS_DEFAULT=3` at the top of
   `scripts/oneonone-join.sh`, plus `--lag-hours <n>`. Nothing else in the repo holds a 3. Widening is
   a one-line edit, and testing a wider value needs no edit at all.
2. **An empty join runs one widening probe before it reports.** When the claim over
   `[event start, event end + 3h]` returns nothing, the command issues one more `list_meetings` over
   `[event start, event end + 12h]` and reports the difference in words: either "no recording in
   either bracket, the meeting was not recorded", or "nothing at +3h, found `<id>` in the +12h
   bracket, so `L` is too tight, raise `LAG_HOURS_DEFAULT`". A silent miss becomes a measured
   falsification on the run where it first happens. The probe is budget-neutral: the empty-join path
   is exactly the path that does not spend the `get_meeting_transcript` call.
3. **Every resolved join records its observed lag.** `state.json` stores
   `meetings["<date>"].lagMinutes`, computed from the recording's `created` field when
   `list_meetings` returns one, and `null` when it does not. After four runs the state file holds the
   distribution `A11` admits it does not have, and Q11's remaining half (is the timestamp readable, or
   only filterable) is answered as a byproduct of the first real run rather than by another
   measurement session.

The instrument is the point. `A11` is right that one sample is not a distribution, and the fix is not
a better guess, it is a run that reports what it saw.

### The `/sweep` lens question

The spec's decisive argument is the cursor: "two commands sharing one `lastRunAt` is a bug that shows
up as a sweep quietly missing a fortnight." **That argument is wrong, and I am saying so loudly.**
`scripts/sweep-window.sh:11` takes `--state` as a parameter and reads `.lastRunAt` from whatever file
it is handed. Nothing forces two commands into one cursor. A `/sweep --oneonone` lens would pass
`--state ~/.claude/polaris-memory/oneonone/state.json` in exactly the way this plan's `/oneonone`
does, and the sweep cursor would never move. The cursor is separable in one argument, so it decides
nothing.

The surface decision survives on the other two arguments, which are the ones to keep:

- **File responsibility.** `commands/sweep.md` is 325 lines with three modes. Its two existing
  bolt-ons are cheap because they pull no source and write no sweep page: `--okr-review` reads three
  OKR files, `--okr-init` reads one doc. A 1:1 mode would add a second full pipeline (a different
  window, a different join, six different sections, a different page title, a different state file),
  roughly doubling the file and failing `rules/core.md`'s one-sentence purpose test outright.
- **The `add` verb has no home in `/sweep` at all.** `/oneonone add ask about the promotion rubric`
  is a capture surface that touches no source, no window, and no page. `/sweep add` would read as a
  sweep. The success metrics name capture as the thing to watch above all others, so the verb that
  carries it should not be buried inside a command named for something else.

Conclusion unchanged, reasoning replaced. If someone later argues the lens again, the counter is the
`add` verb and the 325 lines, never the cursor.

---

## The deterministic line

Core Rule 5: if code can answer, code answers. Each piece is placed, with the reason.

| Piece | Side | Where | Why |
|---|---|---|---|
| Window start, first-run fallback, 21-day cap | code | `sweep-window.sh` | Date arithmetic, already owned by that script, already asserted |
| Inbox append, open-item read, consume | code | `oneonone-inbox.sh` | File edits with an ordering guarantee AC 39 depends on |
| The 5-item cap on `To discuss live` | code | `oneonone-inbox.sh consume` refuses a sixth id | The item set is a file, so the cap is countable. AC 13 |
| The 1:1 structural test (AC 69) | code | `oneonone-join.sh series` | Field predicates: `recurringEventId` present, two attendees, one `self` |
| Title tiebreak (AC 71) | code | same | A case-insensitive match on two literals, not a judgment |
| Forward bracket, `L` (AC 73, 83) | code | same | Timestamp arithmetic |
| Unlabeled test (AC 76) | code | `oneonone-join.sh claim` | Field presence, stated as code by the spec |
| The claiming pass and its verdict (AC 84 to 87) | code | same | Set comparison, string match, and a count |
| Observed ingest lag | code | same | Subtraction, when the field exists |
| OKR cadence due-or-not (AC 16 to 18) | code | one `jq` line in the command | Day arithmetic on `lastOkrCoveredAt` |
| Per-KR pace (AC 20) | code | `okr-pace.sh` unchanged | Already owned |
| Coverage: window dates with no journal entry (AC 9) | code | one shell loop in the command | A file-existence test per date |
| Project discovery for the status grid | code | `find` over `~/.claude/projects` for distinct `cwd` | The same pre-filter `journal-facts.sh:25` already proves |
| Commits and files per project | code | `worktracker-snapshot.sh` unchanged | Already owned |
| Which 12 meetings to summarize (AC 55) | mixed | ordering rule is code, "client attendee" is model | Rank order is stated; who counts as a client is not a field |
| Win selection and phrasing (AC 11) | model | the command | Ranking over a derived set |
| `Top 3 they need to know` (AC 12) | model | the command | Classification plus one-sentence compression |
| Inbox item to section (A3) | model | the command | Classification, deliberately unbucketed at capture time |
| Credential, salary, and third-party omission (AC 44, 68) | model | the command | Judgment over content, with `check-patterns.sh injection` as the deterministic floor |
| The recap proposal (AC 28) | model | the command | Summarization from a transcript |
| Direction inference (AC 78) | **cut** | nowhere in v1 | Decision D2 |

The rule I applied: a piece is code when its inputs are fields and its output is a comparison, a
count, or arithmetic. Everything the spec called derivation over prose stayed with the model.

---

## The join, in full

This is the mechanism someone must be able to implement without re-deriving it.

**Inputs.** One `list_events` result over the window. One `list_meetings` result per 1:1 instance,
bracketed. Nothing else.

**Stage 1, find the series.** Over the events, a candidate instance has `recurringEventId` present,
`attendees | length == 2`, and one attendee with `self == true`. Group candidates by
`recurringEventId`. One group wins outright. More than one group, and the tiebreak is a title matching
`1:1` or `one[- ]on[- ]one`, case-insensitive, on any instance in the group. Still more than one, and
the verdict is `ambiguous`: the command lists them once, the user picks, and the chosen id is written
to `config.json` and read as `--pinned` on every later run. Zero groups is verdict `none`, and the
agenda says the series was not found so a renamed invite is visible. The manager is the non-self
attendee of the winning group, derived and never configured.

**Stage 2, the bracket.** For each instance of the winning series inside the window:
`createdAfter = <instance start>`, `createdBefore = <instance end> + L`, with `L = 3h` from
`LAG_HOURS_DEFAULT`. Forward, because `created` is Fathom's ingest time and an offline recording does
not exist yet when the meeting ends. The 10:20Z to 11:10Z bracket around the observed event returned
zero meetings; 11:10Z to 12:30Z returned `166058462` alone.

**Stage 3, the claiming pass.** Over the bracketed `list_meetings` result, with the other calendar
events in the window supplying their titles and the 1:1 instance supplying its attendee set:

1. **Tier A, exact claim.** A candidate whose `calendar_invitees` email set equals the 1:1 instance's
   attendee email set. This is the strongest possible evidence and it is a set comparison. Such a
   candidate is `labeled: true`.
2. **Tier B, anonymous.** A candidate with `calendar_invitees` absent or empty. This is AC 76's
   predicate. Such a candidate is `labeled: false`.
3. **Dropped.** A candidate with `calendar_invitees` present and not equal to the instance's
   attendees. Another meeting owns it. This removes the SAGE Syncs and the Stand Ups by the same test
   AC 84 wanted, without removing the remote 1:1.
4. **Title claim.** Within tier B, drop any candidate whose title case-insensitively matches the
   title of another calendar event in the window. An `Impromptu Call` matches nothing, so it survives;
   a stray `Stand Up` recording that lost its invitees does not.
5. **The unclaimed set** is tier A when tier A is non-empty, else what remains of tier B. An exact
   invitee match beats an anonymous recording, always, and never the other way round.

**Stage 4, the verdict.** Sorted by `recording_id` ascending, which is display order only.

- Exactly one: `resolved`, and the run says which id it took and whether it is labeled.
- More than one: `ambiguous`. The candidates are listed with title, duration, and id, the lowest id
  offered as the default so the answer is one keystroke, the user picks, and the choice is persisted
  under `state.meetings["<date>"]` so it is asked once and never again. 2026-07-31 holds two
  `Impromptu Call` recordings, so this is a real branch.
- Zero: the widening probe fires, then `none`, with both brackets named.

**Where `L` lives.** `LAG_HOURS_DEFAULT=3`, one assignment, at the top of `scripts/oneonone-join.sh`.
`--lag-hours` overrides it. `commands/oneonone.md` never states a number; it passes the flag only for
the widening probe, where it passes `12`, and that 12 is derived as `4 × L` by the script itself
rather than typed in the command. Task 2 step 4 makes that explicit so a widened `L` widens the probe
with it.

**The call it saves.** Stage 2 and stage 3 are skipped entirely when `state.meetings["<date>"]`
already holds a recording for the instance date, which is AC 74 and AC 75. A second run on the same
fortnight spends one fewer `list_meetings`.

---

## The call ledger

Counted per run so a reviewer can check it. `--offline` is zero across every row.

**Derivation, the AC 54 budget.**

| Call | Count | Note |
|---|---|---|
| `get_identity` | 1 | The self address for the AC 69 test |
| `list_events` over the window, plus the next 1:1 | 1 | One call covers both, AC 70 |
| `list_meetings` over the window | 1 + pages | Paged until exhausted |
| `list_meetings` forward bracket | 1 per 1:1 instance | 0 when `state.meetings` already holds it |
| `get_meeting_summary` | ≤ 12 | AC 55 cap, chosen in the stated order |
| `get_meeting_transcript` | 1 | The previous 1:1 only |
| Jira JQL | 1 | The status-grid ground truth |
| **Total** | **18** | 19 when the fortnight holds two instances |

**Delivery, which AC 54 does not count and should.**

| Call | Count | Note |
|---|---|---|
| Notion create or update | 1 | AC 48, AC 49 |
| Notion fetch of `lastPageId` | 1 | Only on a repeat run for the same date |
| **Total** | **≤ 2** | Never blocks the run, AC 50 |

**Recap.** One `get_meeting_transcript`, one `list_meetings` bracket when the date is not in state,
one Notion append. Three at most.

**The failure paths.** An empty join spends one widening `list_meetings` and zero
`get_meeting_transcript`, so it lands at 18. A source that fails spends fewer. Nothing on any path
exceeds 19 derivation calls.

A run that exceeds either budget is a regression, in the same way an over-count of review agents is.
The command prints `calls:` into the agenda frontmatter, so the count is checkable after the fact
without a rerun.

---

## Failure ordering, as a global constraint

`A7` fixes three stages, and no task may reorder them:

1. **Derive over the network.** A source failure degrades content, names itself under
   `sources not read`, and never guesses a replacement item.
2. **Write the local agenda file, then stdout.** A failure here stops the run: `state.json` is
   untouched, no inbox line is checked, no Notion call is made, and the next run re-covers the same
   window.
3. **Write the Notion page.** A failure here costs the page and nothing else. Exit status stays zero,
   `lastPageUrl` and `lastPageId` are not written, and one line names what failed.

The inbox consume in AC 38 runs after step 2 and before step 3, because AC 39 ties it to the local
write and not to the page. `--dry-run` stops after printing and performs no write of any kind.

Every task below states which stage it touches. Task 7 is the only task that may issue a remote
write, and it may not begin until task 6's local write has succeeded.

---

## Decisions

D1, D2, D3, D9, and D10 clear all three ADR gates: hard to reverse, surprising without context, a real
trade-off. D4 to D8 and D11 are recorded reasoning rather than ledger entries, because each is cheap to
reverse and none gave anything up that is not obvious from its own statement.

### D1 (ADR) The claiming pass ranks by invitee-set match, it does not drop on invitee presence

**Context.** AC 84 drops every candidate carrying `calendar_invitees`, reasoning that a scheduled
meeting is not the in-person 1:1. AC 69 requires the 1:1 to be a calendar event. A remote 1:1 therefore
produces a recording carrying the two attendees of that event, and AC 84 drops the one recording it
was looking for. AC 81's labeled path becomes dead code, and the mode silently only ever works for a
1:1 held in a room.

**Decision.** Compare invitee sets instead of testing presence. An invitee set equal to the instance's
attendee set is an exact claim and outranks everything. An absent or empty invitee set is an anonymous
candidate. Any other invitee set means a different event owns that recording.

**Rejected.** Keeping AC 84 as written and adding a separate remote-1:1 path: two code paths for one
join, and the second one has no observed data behind it either. Keeping AC 84 and accepting that
remote 1:1s never resolve: the failure is silent, and a user whose meeting moved to a video call would
see the continuity section quietly empty with no explanation.

**Given up.** The rule is longer than a presence test, and the set comparison has to normalize email
case and ignore the organizer field. Both are asserted in task 2.

### D2 (ADR) AC 78's grammar-based direction inference does not ship in v1

**Context.** AC 78 proposes that a second-person evaluation in an unlabeled transcript reads as the
manager speaking and a first-person commitment reads as the user. Everything is marked `confirm`. It
is the only soft mechanism in an otherwise field-predicate design, and its failure returns the user's
own words to them as their manager's feedback inside a document they then send to that manager.

**Decision.** Cut it. AC 77, 79, 80, and 81 ship unchanged. An unlabeled recording contributes quoted
content under `To confirm`, attributed to the recording and not to a person, with no direction
proposed.

**The evidence that decided it.** One agenda produced by hand under this spec already exists at
`~/.claude/polaris-memory/oneonone/agendas/2026-08-05-oneonone.md`. Its `Career and feedback` section
is built from the unlabeled 2026-07-22 recording. It opens with "Everything below is what was said in
the room, not who said it", quotes the pace line verbatim under **To confirm**, and is the most useful
section in the file. It proposes no direction anywhere. So the spec's case for AC 78, that without it
an unlabeled recording yields nothing usable for the feedback section, is contradicted by the only run
that exists. What AC 78 would have added is a label on content that was already there and already
usable.

The same file's `## Outcomes`, written after the 2026-08-07 meeting, repeats the hedge unprompted:
"Transcription quality is poor and Fathom did not separate speakers, so everything below is what the
room agreed, not who said it." That is the second unlabeled recording in a row where the user chose,
by hand and on a document they sent to their manager, to state the content and refuse the speaker. A
mechanism that proposes a speaker would be arguing with the user's own demonstrated preference.

**The second reason.** Q14 proposes settling it empirically at a confirmation rate between 20% and
80%. Reading that rate needs roughly ten proposals. At bi-weekly cadence with one unlabeled recording
each, that is five months. A mechanism whose safety check cannot return a verdict inside its own review
horizon should not ship ahead of the evidence.

**Rejected.** Shipping it behind a flag: a flag nobody sets is a mechanism nobody measures, and a flag
the user sets once is the same risk with an extra step. Shipping it and relying on the `confirm`
marker: the persona finding is explicit that an unconfirmed attribution is worse than a blank line,
and a marker on a line the user skims is not a decision.

**Given up.** The direction label is real information when the grammar is unambiguous, and cutting it
means the user supplies direction by hand. That cost is bounded and already paid for: the recap in
AC 28 asks one question, and a human answering "they said that, I said this" is a person deciding rather
than a grammar rule proposing.

**What brings it back.** Count, across four agendas, how many `To confirm` lines the user annotates
with a direction by hand. If they do it on most of them, the rule has a measured job and a measured
shape. If they do not, the spec's Q14 answer was noise and the cut was right.

### D3 (ADR) A second new script, `scripts/oneonone-join.sh`

**Context.** The spec commits to one new script and argues the two field predicates are three lines
each and belong inline as `jq`, with "add the script the moment either predicate grows a third
condition".

**Decision.** Add the script. The join is not two predicates. It is the bracket arithmetic, the
`L` constant, the invitee-set ranking, the title claim, the count-and-decide, the id ordering, the
observed-lag extraction, and the bracket echo for the empty report. That is eight, and the spec's own
trigger fired five conditions ago.

**Rejected.** Inline `jq` in the command, per the spec: it puts the one mechanism most likely to be
wrong on the model side of Rule 5 with no fixture and no assertion, and it scatters `L` across every
place the command computes a bracket. The alternative of folding the join into
`scripts/oneonone-inbox.sh` fails the one-file-one-responsibility test in `rules/core.md`; an inbox
and a calendar join share nothing.

**Given up.** One more file, against a spec that said one. The laziness ladder's rung 2 was checked
first: nothing in `scripts/` does a time-bracketed join, and `worktracker-snapshot.sh` and
`journal-facts.sh` are local-fact extractors with no connector input.

### D4 No routing row and no flow row (resolves Q6 and Q7 together)

Q7's default is a row in the `routing` class of `rules/patterns.json` plus a fixture in
`tests/fixtures/routing-cases.txt`. Q6's default is no row in `rules/flows.json`. The two cannot both
hold: `tests/run-tests.sh:506-511` asserts every routing class is a key in `rules/flows.json`, so the
routing row alone turns the suite red.

Taking both, on the `context` precedent (one class, one single-phase flow running `command:catchup`),
costs three things. `hooks/enhance-prompt:60` would seed a run ledger under the current project's
`.polaris/runs/` for a command whose state is user-level and whose artifact lands in
`~/.claude/polaris-memory/oneonone/`. That run stays open until someone runs `/polaris:pause`
(`scripts/run-state.sh:100-114`), and while it is open every other prompt in that project is treated
as input to it. And `hooks/enhance-prompt:22` exits when the cwd has no `.polaris/config.json`, so the
prose route works only from inside a Polaris project, which a 1:1 agenda is not.

Decision: neither row. Typing `/oneonone` is nine characters and it works from any directory. Revisit
if the user reports typing the prose form and landing nowhere.

### D5 The call budget is two budgets, not one

AC 54's eighteen counts derivation only. Restating it as eighteen derivation plus two delivery keeps
AC 54's number intact, matches the stage split A7 already draws, and makes the budget one a conforming
run can actually hold. The rushed persona cares about the derivation number, because the local file
and the stdout copy are written before the first Notion call.

### D6 The status grid reads Jira first and `streams.md` second (resolves Q9)

Q9's default is `streams.md` plus the Jira JQL plus the projects named in the window's journals.
Checked against the artifact that exists: the 2026-08-05 grid has 12 rows, nine of them SAGE Jira
issues and three of them finished-but-uncommitted branches that Jira cannot see. So both sources earn
their place, with Jira as the spine and `streams.md` supplying what has no ticket.

The default's third clause needs fixing. Journal frontmatter carries `projects:` as basenames
(`projects: [SF, Sage, polaris, sections, runs, ...]`, 18 entries on 2026-08-04, several of them
worktrees and stray directories), and a basename does not resolve to a path. The deterministic project
list is the distinct `cwd` over the window's transcripts, which is the pre-filter
`scripts/journal-facts.sh:25` already proves works. Task 5 uses that, and reads
`<cwd>/.polaris/work/streams.md` where it exists.

### D7 The OKR cadence stays derived, and the recap writes nothing under `okr/` (resolves Q3 and Q4)

Q3 keeps its default. `ledger.md:5` states "Review cadence: every 2 months", the request says monthly,
and those are two rhythms: the monthly agenda section is not the bi-monthly review doc, and AC 23
already links the review rather than re-deriving it. The threshold is 28 days on `lastOkrCoveredAt`,
which at bi-weekly cadence catches every other 1:1, and AC 16's 31-day case and AC 17's 14-day case
both fall the right side of it. `~/.claude/polaris-memory/okr/reviews/` does not exist today, so
AC 23's "run `/sweep --okr-review` first" line fires on the first real run.

Q4 keeps its default of no. Two writers on one append-only ledger with no locking, and
`/sweep --okr-review` rebuilds each KR's `current` by summing the log's deltas, so a duplicate entry
double-counts a KR. The collision is not hypothetical: `log.md` holds a `/sweep` evening entry for
every day including 2026-08-07, the day the 1:1 was actually held, which carries
`O1-KR1 +1`. A recap writing that same movement would have produced two entries for one event.

### D8 No rapport prompts (resolves Q8)

Default kept, and the artifact supports it. The 2026-08-05 agenda already carries five live items, six
role questions, and four asks against a 45-minute slot with 20 to 30 minutes of discussion. The real
meeting then reached none of the five live items, which settles it: the slot is over-subscribed by a
factor of two before any small talk is added. Nothing in v1.

### D9 (ADR) A second run never overwrites an edited agenda

**Context.** AC 34 rewrites the one dated file on a repeat run. Two of the user's corrections on a
generated draft say that is wrong: "concierge onboarding isn't built by me, don't count it" is a
derived attribution the user fixed by hand, and "what I removed should have stayed removed" is that
fix being destroyed. Derived attribution from `git log` and Jira is wrong some of the time by
construction, because a commit in a repo is not proof the user wrote the feature. A run that rewrites
the file makes every correction cost the same effort twice.

**Decision.** `state.json` records `lastAgendaSha`, the hash of what the run wrote. A later run for the
same date hashes the file on disk first. Equal means the user did not touch it, so rewrite it, which
is AC 34's naive case and stays exactly as specified. Different means the user edited it, so write
nothing: print the full rendered agenda to stdout, name the file that was left alone, and say what is
new since the last run. `--force` rewrites anyway and says it discarded an edit. The Notion page
follows the local file by the A7 ordering: no local write means no page write, so the page keeps the
edit too.

**Rejected.** A suppression list keyed on stable source keys (Jira key, PR number, recording id), so a
removed item is remembered as removed and never re-derived. It is the better answer in the abstract
and it is speculative machinery for a command that runs twice a fortnight: it needs a key on every
derived item, a scanner that finds keys in an edited body, and a rule for a user who rewords rather
than deletes. Build it if the stdout path is actually annoying in practice, which four runs will say.
Also rejected: asking the user whether to overwrite. A question at agenda time costs the rushed
persona, and the answer is always the same one.

**Given up.** A second run on an edited file produces no file, so the user merges by hand. That is a
real cost, paid to make the guarantee absolute rather than probabilistic. An edit is never lost.

**AC 34 changes to:** one artifact per date on both sides, rewritten on a repeat run only when the
file on disk still matches what the last run wrote.

### D10 (ADR) Unraised agenda items carry forward, through the artifact and through the inbox

**Context.** The real recap's `### Not raised` lists seven prepared items the meeting never reached and
closes with "carry the six unraised items into the next 1:1". No AC covers it. R5's continuity is
entirely about actions that came out of a meeting; an item prepared and never discussed is its
opposite, and it is the normal outcome of a slot that holds nine sections and 25 minutes of discussion.
The first real meeting reached zero of the five prepared live items.

**Decision.** Two mechanisms, because they carry different things.

1. **The recap writes `### Not raised` into `## Outcomes`**, listing every prepared item the transcript
   does not touch. The next assemble reads the previous agenda's `### Not raised` as a third continuity
   input beside the transcript and `## Outcomes`. This carries derived items, which have no other home:
   "Sprint 28 scope against Friday" was never an inbox item and would otherwise vanish.
2. **The recap restores the unraised inbox items to open.** AC 38 marks an item `- [x] · raised <date>`
   when it reaches `To discuss live`. If the meeting never reached it, that mark is false and the item
   should compete for the next agenda's five slots on its merits. `oneonone-inbox.sh restore` flips
   those lines back to `- [ ]`, and task 3 adds it.

Mechanism 1 alone would carry the item as a line under `Open from last time`, where AC 13's ranking
never reconsiders it, so it would be visible and never discussed a second time. Mechanism 2 alone loses
every derived item. Both, or neither works.

**Rejected.** A separate carry-forward state file. `state.json` already exists and the artifact already
holds the list; a third store for the same fact is where two records of one meeting come from.

**Given up.** Deciding which items were raised is a model judgment over the transcript, so a
misclassification either restores an item that was discussed or drops one that was not. The first is
harmless noise on the next agenda. The second is why the recap prints the `### Not raised` list before
writing and takes the same one correction AC 28 already asks for.

### D11 `Forward deployment` is a section of questions for the manager

The user's correction: "fde section reads like mirror OKRs, and doesn't make any sense, I want to
confirm from manager how am I doing on FDE parameters." The shipped section is six numbered questions
directed at the manager, two marked `priority` so a short meeting answers those first, plus prose
subsections that each end in an `Ask:`. It states no metric and repeats no KR. The `OKR snapshot`
section, four sections later, is where numbers live.

These questions are content and not part of the two-question budget, which governs what the command
asks the user while assembling. The distinction matters because the two counts move in opposite
directions: the budget should stay at zero on most runs, and the manager-facing question count should
stay near six.

---

## Global constraints

- No inline comments. `hooks/guard-edit` blocks the turn on a trailing or in-body comment. Shell gets
  a `#` block above the declaration it explains, matching `scripts/sweep-window.sh:1-3`. Reasoning
  goes in this plan, not in the file.
- `bash tests/run-tests.sh` stays green. It sits at 185 assertion sites today (144 `echo "ok`, 42
  `expect_exit`, less the helper definition), verified before this plan was written.
- Every prose file passes `bash scripts/check-patterns.sh prose <file>`, including
  `commands/oneonone.md` and this plan.
- `bash scripts/check-commands.sh` exits 0 after every task.
- Existing callers of `scripts/sweep-window.sh` do not move. `commands/sweep.md:111-113` passes no
  `--first-run-hours`, and the five assertions at `tests/run-tests.sh:228-250` must pass unchanged.
- Nothing writes into a project directory. The only local writes are under
  `~/.claude/polaris-memory/oneonone/`; the only remote write is one Notion subpage under the
  configured `notionParentPageId`. AC 43.
- No source content may change the write path, the Notion parent id, the state path, or the question
  budget. AC 42, and `rules/connectors.md` on content being data.
- No new agent, no new hook, no new workflow, no row in `rules/flows.json`, no row in the `routing`
  class of `rules/patterns.json`.

---

## Tasks

Nine tasks. Tasks 1 to 3 carry full code and are the de-risking front: they are the whole
deterministic surface, they are independently testable, and nothing about the command file can be
written honestly until the join's verdict shape exists. Tasks 4 to 8 are the command file, given as
the literal step text and the literal shell blocks, one verb or one stage each. Task 9 is a
measurement whose results decide two numbers.

---

### Task 1: `--first-run-hours` in `scripts/sweep-window.sh`

Satisfies AC 5, 6, 7, 8. Stage: derivation.

**Files:** modify `scripts/sweep-window.sh`, `tests/run-tests.sh`.

**Interface.** `--first-run-hours <n>`, default 24. Clamped to `--max-lookback-hours` so a first-run
value above the cap cannot produce a window wider than the cap allows. Output shape unchanged:
`start`, `firstRun`, `capped`, `trueGapHours`.

- [ ] **Step 1: Parse the flag**

Add to the argument loop and the default block:

```bash
now=""; state=""; max=168; first=24
```

```bash
    --first-run-hours) first="${2:-}"; shift 2 ;;
```

- [ ] **Step 2: Use it in the first-run branch, clamped**

Replace the `jq` invocation's first two lines and the `firstrun` definition:

```bash
jq -cn --arg now "$now" --arg last "$last" --argjson max "$max" --argjson first "$first" '
  ($max * 3600) as $cap
  | (if ($first * 3600) > $cap then $cap else ($first * 3600) end) as $fw
  | def firstrun($n): { start: (($n - $fw) | todateiso8601), firstRun: true, capped: false, trueGapHours: (($fw / 3600) | floor) };
```

`$cap` moves above `firstrun` because the clamp needs it. The rest of the filter is unchanged, and
`$cap` is no longer redefined below.

The clamp is one expression and it is the edge case worth being correct on: a caller passing
`--first-run-hours 1000 --max-lookback-hours 168` means "a long first window, capped at a week", and
without the clamp it silently gets a 1000-hour window from a script whose whole job is bounding one.

- [ ] **Step 3: Three assertions beside the existing five**

Append after `tests/run-tests.sh:249`:

```bash
sw6="$(bash "$SW" --now 2026-08-03T00:00:00Z --state /nonexistent-state --first-run-hours 336 --max-lookback-hours 504)"
echo "$sw6" | jq -e '.firstRun==true and .start=="2026-07-20T00:00:00Z" and .trueGapHours==336' >/dev/null \
  && echo "ok: sweep-window first-run-hours widens the first window" || { echo "FAIL: sweep-window first-run-hours ($sw6)"; fail=1; }
sw7="$(bash "$SW" --now 2026-08-03T00:00:00Z --state /nonexistent-state --max-lookback-hours 504)"
echo "$sw7" | jq -e '.start=="2026-08-02T00:00:00Z" and .trueGapHours==24' >/dev/null \
  && echo "ok: sweep-window first run stays 24h without the flag" || { echo "FAIL: sweep-window default first run moved ($sw7)"; fail=1; }
sw8="$(bash "$SW" --now 2026-08-03T00:00:00Z --state /nonexistent-state --first-run-hours 1000 --max-lookback-hours 168)"
echo "$sw8" | jq -e '.start=="2026-07-27T00:00:00Z" and .trueGapHours==168' >/dev/null \
  && echo "ok: sweep-window clamps first-run-hours to the cap" || { echo "FAIL: sweep-window first-run clamp ($sw8)"; fail=1; }
```

`sw7` is the regression that matters. `/sweep` is the one existing caller and it passes no flag; if
its first run stops being 24 hours, this task broke a shipped command.

**Check:** `bash tests/run-tests.sh` green, 8 `sweep-window` assertions where there were 5.

---

### Task 2: `scripts/oneonone-join.sh`

Satisfies AC 57, 66, 69, 70, 71, 72, 73, 76, 83, 84, 85, 86, 87. Stage: derivation, and it makes no
call of its own. Decision D1 and D3.

**Files:** create `scripts/oneonone-join.sh`, `tests/fixtures/oneonone-events.json`,
`tests/fixtures/oneonone-meetings.json`; modify `tests/run-tests.sh`.

**Interfaces.**

```
oneonone-join.sh series --self <email> [--pinned <recurringEventId>] [--lag-hours <n>] < list_events.json
oneonone-join.sh claim  --attendees <a,b> [--titles <file>] [--lag-hours <n>] < list_meetings.json
```

`series` consumes the `list_events` array and emits one object:

```json
{ "status": "ok",
  "recurringEventId": "da2d…",
  "manager": { "email": "manager@example.com", "name": "Manager Example" },
  "lagHours": 3,
  "instances": [ { "date": "2026-07-22", "start": "…T10:30:00Z", "end": "…T11:00:00Z",
                   "title": "1:1 Manager / Self",
                   "createdAfter": "…T10:30:00Z", "createdBefore": "…T14:00:00Z" } ],
  "otherTitles": [ "Client Sync", "Stand Up", "Weekly review + plan" ] }
```

`status` is `ok`, `ambiguous` (with `candidates`), or `none`. `otherTitles` is every non-candidate
event title in the window, deduplicated, so `claim` needs no second read of the events.

`claim` consumes the bracketed `list_meetings` array and emits:

```json
{ "status": "resolved", "recordingId": 166058462, "url": "https://fathom.video/calls/…",
  "labeled": false, "lagMinutes": 47, "tier": "B" }
```

or `{"status":"ambiguous","candidates":[…],"default":166058462}` or
`{"status":"none","bracket":{"createdAfter":"…","createdBefore":"…"}}`.

- [ ] **Step 1: The header and the one constant**

```bash
#!/usr/bin/env bash
# Resolve the manager 1:1 from calendar structure, and join that interval to its Fathom recording.
# Deterministic: the command must not do this arithmetic or these field tests itself (core Rule 5).
# Two subcommands. `series` reads a list_events array and picks the recurring two-attendee series,
# emitting each instance with its forward ingest bracket. `claim` reads the bracketed list_meetings
# array for one instance and returns resolved, ambiguous, or none.
set -uo pipefail

LAG_HOURS_DEFAULT=3
```

`LAG_HOURS_DEFAULT` is the only place in the repo holding this number. Task 4 forbids the command file
from writing a bracket of its own.

- [ ] **Step 2: `series`**

```bash
cmd_series() {
  jq -c --arg self "$self" --arg pinned "$pinned" --argjson lag "$lag" '
    def emails: [ .attendees[]? | (.email // "") | ascii_downcase ] | sort;
    def isself($a): (($a.self // false) == true) or (($a.email // "" | ascii_downcase) == ($self | ascii_downcase));
    def cand: select((.recurringEventId // "") != "")
            | select((.attendees // []) | length == 2)
            | select([ .attendees[] | select(isself(.)) ] | length == 1);
    . as $all
    | [ .[] | cand ] as $c
    | ($c | group_by(.recurringEventId)) as $groups
    | (if ($pinned | length) > 0
       then [ $groups[] | select(.[0].recurringEventId == $pinned) ]
       else $groups end) as $g0
    | (if ($g0 | length) > 1
       then ([ $g0[] | select(any(.[]; (.summary // "") | ascii_downcase | test("1:1|one[- ]on[- ]one"))) ]
             | if length == 1 then . else $g0 end)
       else $g0 end) as $g
    | if ($g | length) == 0 then { status: "none" }
      elif ($g | length) > 1 then
        { status: "ambiguous",
          candidates: [ $g[] | { recurringEventId: .[0].recurringEventId,
                                 title: (.[0].summary // ""), instances: length } ] }
      else
        ($g[0]) as $s
        | ($s[0].attendees | map(select(isself(.) | not)) | .[0]) as $mgr
        | { status: "ok",
            recurringEventId: $s[0].recurringEventId,
            manager: { email: ($mgr.email // ""), name: ($mgr.displayName // $mgr.email // "") },
            lagHours: $lag,
            instances: [ $s[] | (.start.dateTime // .start.date) as $st | (.end.dateTime // .end.date) as $en
              | { date: ($st | fromdateiso8601 | strftime("%Y-%m-%d")),
                  start: $st, end: $en, title: (.summary // ""),
                  createdAfter: $st,
                  createdBefore: (($en | fromdateiso8601) + ($lag * 3600) | todateiso8601) } ],
            otherTitles: ([ $all[] | select((.recurringEventId // "") == "" or (.attendees // [] | length) != 2)
                          | (.summary // "") | select(length > 0) ] | unique) }
      end'
}
```

Four things in there are load-bearing. `isself` accepts either the `self` boolean or an email match,
because Google Calendar sets `self` on the acting user's own attendee record and the `--self` address
from `get_identity` is the fallback when it does not. The self count must be exactly 1, so a
two-attendee event where neither is the user is not a candidate. The title tiebreak only narrows when
it narrows to exactly one, so two events both titled `1:1` stay ambiguous rather than picking the
first. And `otherTitles` deliberately excludes the candidate series' own title, so the title claim in
`claim` can never drop the 1:1's own recording.

- [ ] **Step 3: `claim`**

```bash
cmd_claim() {
  local titles="[]"
  [ -n "$titles_file" ] && [ -f "$titles_file" ] && titles="$(jq -Rc '[inputs | ascii_downcase]' "$titles_file")"
  jq -c --argjson titles "$titles" --arg att "$attendees" \
        --arg ca "$created_after" --arg cb "$created_before" '
    def inv: [ .calendar_invitees[]? | (.email // "") | ascii_downcase ] | sort;
    ($att | ascii_downcase | split(",") | map(select(length > 0)) | sort) as $want
    | [ .[] | . + { _inv: inv } ] as $all
    | [ $all[] | select((._inv | length) > 0 and ._inv == $want) ] as $tierA
    | [ $all[] | select((._inv | length) == 0)
              | select((.title // "" | ascii_downcase) as $t | ($titles | index($t)) == null) ] as $tierB
    | (if ($tierA | length) > 0 then $tierA else $tierB end) as $un
    | ($un | sort_by(.recording_id)) as $s
    | def shape($m; $labeled):
        { status: "resolved", recordingId: $m.recording_id, url: ($m.url // ""),
          labeled: $labeled, tier: (if $labeled then "A" else "B" end),
          lagMinutes: (if ($m.created // null) == null then null
                       else ((($m.created | fromdateiso8601) - ($ca | fromdateiso8601)) / 60 | floor) end) };
      if ($s | length) == 1 then shape($s[0]; ($tierA | length) > 0)
      elif ($s | length) > 1 then
        { status: "ambiguous", default: $s[0].recording_id,
          candidates: [ $s[] | { recordingId: .recording_id, title: (.title // ""),
                                 durationMinutes: (.duration_minutes // null), url: (.url // "") } ] }
      else { status: "none", bracket: { createdAfter: $ca, createdBefore: $cb } } end'
}
```

The tier A test requires a non-empty invitee set as well as equality, so a candidate with no invitees
and a 1:1 with no attendees cannot match each other by both being empty. `lagMinutes` is measured from
`createdAfter`, which is the event start, so the number recorded is time from meeting start to ingest
and is directly comparable to the 40-to-90-minute observation behind `A11`. It is `null` when
`list_meetings` does not return `created`, which is Q11's open half; the first real run answers it.

- [ ] **Step 4: The widening probe factor**

Add one subcommand so the command file never types a widened number:

```bash
cmd_widen() { echo $(( ${lag} * 4 )); }
```

Task 5 calls `oneonone-join.sh widen --lag-hours "$lag"` for the probe bracket. Raising
`LAG_HOURS_DEFAULT` from 3 to 5 raises the probe from 12 to 20 with no second edit. `A11` asks for one
named constant; this is what keeps it to one.

- [ ] **Step 5: Two fixtures, captured from one real run and redacted**

`tests/fixtures/oneonone-events.json`: the 2026-07-20 to 2026-08-04 `list_events` result, reduced to
the fields the script reads (`summary`, `start`, `end`, `attendees[].email`, `attendees[].self`,
`recurringEventId`). It must contain the real `1:1 Manager / Self` instance, at least two Client
Syncs with more than two attendees, one two-attendee non-recurring event, and one of the recurring OKR
blocks.

`tests/fixtures/oneonone-meetings.json`: the bracketed `list_meetings` result, reduced to
`recording_id`, `title`, `url`, `duration_minutes`, `created`, `calendar_invitees[].email`. It must
contain `166058462` with no invitees, a SAGE Sync recording with invitees that do not match, and the
two 2026-07-31 `Impromptu Call` recordings.

Redaction rule: real recording ids and the manager's work address stay, because AC 69 and AC 87 are
asserted against the observed values and a synthetic fixture would assert nothing about the real data.
Nothing else from any transcript enters a fixture.

- [ ] **Step 6: Twelve assertions**

Append to `tests/run-tests.sh` after the `okr-pace` block:

```bash
# oneonone-join: the structural 1:1 test, the forward bracket, and the claiming pass
OJ="${DIR}/../scripts/oneonone-join.sh"
oj_ev="${DIR}/fixtures/oneonone-events.json"
oj_mt="${DIR}/fixtures/oneonone-meetings.json"
oj1="$(bash "$OJ" series --self self@example.com < "$oj_ev")"
echo "$oj1" | jq -e '.status=="ok" and .manager.email=="manager@example.com"' >/dev/null \
  && echo "ok: oneonone-join derives the manager from the two-attendee series" || { echo "FAIL: oneonone-join series ($oj1)"; fail=1; }
echo "$oj1" | jq -e '.instances[0].createdAfter==.instances[0].start' >/dev/null \
  && echo "ok: oneonone-join brackets forward from the event start" || { echo "FAIL: oneonone-join bracket start"; fail=1; }
echo "$oj1" | jq -e '(.instances[0].createdBefore|fromdateiso8601) - (.instances[0].end|fromdateiso8601) == 10800' >/dev/null \
  && echo "ok: oneonone-join applies L as three hours by default" || { echo "FAIL: oneonone-join default L"; fail=1; }
oj2="$(bash "$OJ" series --self self@example.com --lag-hours 12 < "$oj_ev")"
echo "$oj2" | jq -e '(.instances[0].createdBefore|fromdateiso8601) - (.instances[0].end|fromdateiso8601) == 43200 and .instances[0].createdAfter==.instances[0].start' >/dev/null \
  && echo "ok: oneonone-join lag-hours moves only the far edge" || { echo "FAIL: oneonone-join lag-hours"; fail=1; }
echo "$oj1" | jq -e '[.otherTitles[] | select(test("1:1"))] | length == 0' >/dev/null \
  && echo "ok: oneonone-join keeps the series title out of otherTitles" || { echo "FAIL: oneonone-join otherTitles"; fail=1; }
[ "$(bash "$OJ" widen --lag-hours 3)" = 12 ] && [ "$(bash "$OJ" widen --lag-hours 5)" = 20 ] \
  && echo "ok: oneonone-join derives the widening probe from L" || { echo "FAIL: oneonone-join widen"; fail=1; }
oj3="$(bash "$OJ" claim --attendees manager@example.com,self@example.com < "$oj_mt")"
echo "$oj3" | jq -e '.status=="resolved" and .recordingId==166058462 and .labeled==false and .tier=="B"' >/dev/null \
  && echo "ok: oneonone-join resolves the unlabeled in-person recording" || { echo "FAIL: oneonone-join claim ($oj3)"; fail=1; }
oj4="$(jq -c '[.[] | if .recording_id==166058462 then .calendar_invitees=[{email:"manager@example.com"},{email:"self@example.com"}] else . end]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com)"
echo "$oj4" | jq -e '.status=="resolved" and .recordingId==166058462 and .labeled==true and .tier=="A"' >/dev/null \
  && echo "ok: oneonone-join claims a remote 1:1 by exact invitee match" || { echo "FAIL: oneonone-join tier A ($oj4)"; fail=1; }
printf 'Client Sync\nTeam Stand Up\n' > "${DIR}/oj-titles.tmp"
oj5="$(jq -c '[.[] | if .recording_id==166058462 then .title="Client Sync" else . end]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com --titles "${DIR}/oj-titles.tmp")"
echo "$oj5" | jq -e '.status=="none"' >/dev/null \
  && echo "ok: oneonone-join drops a candidate another event explains" || { echo "FAIL: oneonone-join title claim ($oj5)"; fail=1; }
rm -f "${DIR}/oj-titles.tmp"
oj6="$(jq -c '[.[] | select((.calendar_invitees // []) | length == 0)]' "$oj_mt" \
  | bash "$OJ" claim --attendees manager@example.com,self@example.com)"
echo "$oj6" | jq -e '.status=="ambiguous" and .default==(.candidates[0].recordingId) and (.candidates | length) > 1' >/dev/null \
  && echo "ok: oneonone-join refuses to pick among unclaimed candidates" || { echo "FAIL: oneonone-join ambiguous ($oj6)"; fail=1; }
oj7="$(echo '[]' | bash "$OJ" claim --attendees a@b.c,d@e.f --created-after 2026-07-22T10:30:00Z --created-before 2026-07-22T14:00:00Z)"
echo "$oj7" | jq -e '.status=="none" and .bracket.createdBefore=="2026-07-22T14:00:00Z"' >/dev/null \
  && echo "ok: oneonone-join names the bracket it searched" || { echo "FAIL: oneonone-join empty bracket ($oj7)"; fail=1; }
oj8="$(bash "$OJ" claim --attendees manager@example.com,self@example.com --created-after 2026-07-22T10:30:00Z < "$oj_mt")"
echo "$oj8" | jq -e '.lagMinutes != null and .lagMinutes > 0' >/dev/null \
  && echo "ok: oneonone-join records the observed ingest lag" || { echo "FAIL: oneonone-join lagMinutes ($oj8)"; fail=1; }
```

Twelve assertions. `oj4` is D1: without the invitee-set ranking it returns `none` and the remote 1:1
is unreachable. `oj6` is AC 85 against the real 2026-07-31 pair. `oj8` is the `A11` instrument and it
is `null`-tolerant by design, so it will need reading rather than trusting on the first run: if
`created` is absent from the live payload it fails here and the fixture is what is wrong, not the
script.

**Check:** `bash tests/run-tests.sh` green, `bash -n scripts/oneonone-join.sh`, and
`bash scripts/oneonone-join.sh series --self x < /dev/null` exits without a stack trace.

---

### Task 3: `scripts/oneonone-inbox.sh`

Satisfies AC 1, 2, 3, 4, 13, 38, 39, 40, 41, and D10's second mechanism. Stage: local write.

**Files:** create `scripts/oneonone-inbox.sh`; modify `tests/run-tests.sh`.

**Interface.**

```
oneonone-inbox.sh add [--date YYYY-MM-DD] <text…>
oneonone-inbox.sh list
oneonone-inbox.sh consume --date YYYY-MM-DD <n> [<n>…]
oneonone-inbox.sh restore --date YYYY-MM-DD [<n>…]
```

`--date` exists so the caller passes the date already resolved in the sweep config timezone and the
script never guesses one. It defaults to `date +%F` for a bare `/oneonone add` from the shell.

Storage, one item per line, appended:

```
- [ ] 2026-08-03 · ask about the promotion rubric
- [x] 2026-07-20 · pause mechanism question · raised 2026-08-05
```

- [ ] **Step 1: `add`**

`mkdir -p "$INBOX_DIR"`. The item text is `"$*"` with every newline, carriage return, and tab
collapsed to a space and runs of spaces squeezed, so AC 4's item count equals the line count. Empty
after collapsing means write nothing, print
`oneonone add: nothing to add; pass the item text` to stderr, exit 2 (AC 3). Otherwise append the line
and print one line naming the file and the open count: `~/.claude/polaris-memory/oneonone/inbox.md · 4 open`
(AC 1). Append with `>>` so no existing line is rewritten (AC 2). An item over 500 characters is
stored whole; the truncation in the edge-case table is the agenda's job, not the store's.

- [ ] **Step 2: `list`**

Number the `- [ ]` lines only, 1-based over open items in file order, and emit TSV
(`n<TAB>date<TAB>text`) so the command can read it without parsing prose. Checked lines are skipped
and left as history (AC 40). A line matching neither form goes to stderr as
`inbox: line <N> does not parse` and the exit stays 0, which is the edge-case row: read what parses,
name what did not, write nothing back.

- [ ] **Step 3: `consume`**

Refuse more than five ids, print `inbox consume: at most 5 items per agenda`, write nothing, exit 2.
That is AC 13's cap enforced where the item set is a file rather than trusted to prose. Refuse an id
that is out of range or already checked, name it, write nothing, exit 2. Otherwise rewrite the named
open lines to `- [x] … · raised <date>` through a temp file and one `mv`, so a failure mid-write
cannot half-consume the inbox. Print the count consumed.

- [ ] **Step 4: `restore`**

The inverse of `consume`, for D10: an item marked `· raised <date>` that the meeting never reached is
not raised, and the mark is false. `restore --date <agenda-date>` with no ids restores every line
carrying that date; with ids, it restores the numbered subset, numbered over that date's consumed
lines in file order. It strips the `· raised <date>` suffix and flips `- [x]` back to `- [ ]`, through
the same temp file and one `mv`. It refuses a date with no consumed lines and says so. It never touches
a line consumed on a different date, which is what keeps an old agenda's history intact.

- [ ] **Step 5: Fourteen assertions**

```bash
# oneonone-inbox: capture, read, and consume, against an isolated HOME
OI="${DIR}/../scripts/oneonone-inbox.sh"
oi_home="$(mktemp -d)"
oi() { HOME="$oi_home" bash "$OI" "$@"; }
oi_file="$oi_home/.claude/polaris-memory/oneonone/inbox.md"
oi_out="$(oi add --date 2026-08-03 ask about the promotion rubric)"
[ -f "$oi_file" ] && grep -qxF -- '- [ ] 2026-08-03 · ask about the promotion rubric' "$oi_file" \
  && echo "ok: oneonone-inbox add creates the file and the item" || { echo "FAIL: oneonone-inbox add"; fail=1; }
grep -q 'inbox.md' <<<"$oi_out" && grep -q '1' <<<"$oi_out" \
  && echo "ok: oneonone-inbox add names the file and the count" || { echo "FAIL: oneonone-inbox add report ($oi_out)"; fail=1; }
oi_first="$(head -1 "$oi_file")"
oi add --date 2026-08-04 second thing >/dev/null
[ "$(head -1 "$oi_file")" = "$oi_first" ] && [ "$(grep -c '^- \[ \]' "$oi_file")" = 2 ] \
  && echo "ok: oneonone-inbox appends without rewriting" || { echo "FAIL: oneonone-inbox append"; fail=1; }
oi_before="$(cat "$oi_file")"
oi add >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox refuses an empty add" || { echo "FAIL: oneonone-inbox empty add (rc=$oi_rc)"; fail=1; }
oi add --date 2026-08-04 "$(printf 'multi\nline thought')" >/dev/null
[ "$(grep -c '^- \[ \]' "$oi_file")" = 3 ] && [ "$(wc -l < "$oi_file")" = 3 ] \
  && echo "ok: oneonone-inbox collapses a newline into one line" || { echo "FAIL: oneonone-inbox newline"; fail=1; }
printf -- '- [x] 2026-07-01 · old thing · raised 2026-07-15\n' >> "$oi_file"
[ "$(oi list | wc -l | tr -d ' ')" = 3 ] \
  && echo "ok: oneonone-inbox list skips consumed items" || { echo "FAIL: oneonone-inbox list"; fail=1; }
oi list | head -1 | grep -q '^1	2026-08-03	ask about the promotion rubric$' \
  && echo "ok: oneonone-inbox list numbers open items as tsv" || { echo "FAIL: oneonone-inbox list shape"; fail=1; }
printf 'not an item at all\n' >> "$oi_file"
oi_err="$(oi list 2>&1 >/dev/null)"; oi_rc=$?
[ "$oi_rc" = 0 ] && grep -q 'does not parse' <<<"$oi_err" \
  && echo "ok: oneonone-inbox names an unparsable line and keeps going" || { echo "FAIL: oneonone-inbox unparsable ($oi_err)"; fail=1; }
oi consume --date 2026-08-05 1 3 >/dev/null
[ "$(grep -c '^- \[x\].*raised 2026-08-05' "$oi_file")" = 2 ] && [ "$(grep -c '^- \[ \]' "$oi_file")" = 1 ] \
  && echo "ok: oneonone-inbox consumes exactly the named items" || { echo "FAIL: oneonone-inbox consume"; fail=1; }
oi_before="$(cat "$oi_file")"
oi consume --date 2026-08-05 1 2 3 4 5 6 >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox refuses more than five per agenda" || { echo "FAIL: oneonone-inbox cap (rc=$oi_rc)"; fail=1; }
oi consume --date 2026-08-05 99 >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox refuses an out-of-range item" || { echo "FAIL: oneonone-inbox range (rc=$oi_rc)"; fail=1; }
oi_out="$(HOME=/nonexistent-home bash "$OI" list 2>&1)"; oi_rc=$?
[ "$oi_rc" = 0 ] && [ -z "$(HOME=/nonexistent-home bash "$OI" list 2>/dev/null)" ] \
  && echo "ok: oneonone-inbox list on a missing inbox is empty, not an error" || { echo "FAIL: oneonone-inbox missing ($oi_out)"; fail=1; }
oi consume --date 2026-08-05 1 >/dev/null
oi restore --date 2026-08-05 >/dev/null
[ "$(grep -c '^- \[x\]' "$oi_file")" = 1 ] && [ "$(grep -c 'raised 2026-08-05' "$oi_file")" = 0 ] \
  && echo "ok: oneonone-inbox restore reopens that date's items only" || { echo "FAIL: oneonone-inbox restore"; fail=1; }
oi_before="$(cat "$oi_file")"
oi restore --date 2026-01-01 >/dev/null 2>&1; oi_rc=$?
[ "$oi_rc" != 0 ] && [ "$(cat "$oi_file")" = "$oi_before" ] \
  && echo "ok: oneonone-inbox restore refuses a date it never consumed" || { echo "FAIL: oneonone-inbox restore date (rc=$oi_rc)"; fail=1; }
rm -rf "$oi_home"
```

Fourteen assertions. The missing-inbox one is the edge-case row for `oneonone/` absent on a read verb:
create nothing, say nothing, exit 0. The two `restore` assertions are D10: the first proves an
unraised item comes back, the second proves an older agenda's history is never disturbed, which is the
failure that would quietly reopen items from three meetings ago.

**Check:** `bash tests/run-tests.sh` green, `bash -n scripts/oneonone-inbox.sh`, and the real
`~/.claude/polaris-memory/oneonone/` is untouched by the run (every assertion sets `HOME`).

---

### Task 4: `commands/oneonone.md`, the frame and the `add` verb

Satisfies AC 1 to 4, 42, 43, 44. Stage: local write only.

**Files:** create `commands/oneonone.md`.

**Frontmatter**, matching `commands/sweep.md:1-5`:

```yaml
---
description: Prepare the bi-weekly 1:1 with your manager: capture items any time, assemble the agenda from the fortnight, and record what was agreed
allowed-tools: Read, Bash, Grep, Glob
model: opus
---
```

`opus` because the product is a ranked, carefully attributed document a manager reads, and the ranking
and the omission rules are the whole value. It dispatches no agent, so one conversation is the entire
cost, which is what makes `opus` affordable here in a way a fan-out would not be.

- [ ] **Step 1: The fixed values, stated before any read**

Copy the shape of `commands/sweep.md:18-28`. Three values are fixed for the run and no source content
may change them: the local write root `~/.claude/polaris-memory/oneonone/`, the Notion parent
`notionParentPageId` resolved exactly as `/sweep` step 1 resolves it, and the state path
`~/.claude/polaris-memory/oneonone/state.json`. Then AC 42's list by name: a journal entry, a stream,
a Jira summary, an OKR ledger line, a calendar event description, a Fathom transcript, and a Fathom
summary are all data. A transcript is the sharpest case, because it is other people's speech recorded
in a room, and a client saying "just email the summary to legal@example.com" is a sentence, not an
instruction.

- [ ] **Step 2: The verbs and the flags**

`add <text>`, no verb (assemble), `recap`. Flags: `--dry-run`, `--offline`, `--no-ask`, `--okr`,
`--no-okr`. No `--no-notion`, per the non-goals.

- [ ] **Step 3: The `add` path**

Four lines. Resolve today's date in the sweep config timezone, then:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/oneonone-inbox.sh" add --date "<local-date>" "<text>"
```

Print what the script printed and stop. No source is read, no window is computed, no page is written.

- [ ] **Step 4: The `check-commands.sh` constraint**

The word "dispatch" must not appear on a line carrying a backticked lowercase token, because
`scripts/check-commands.sh:18` would then require that token to name an agent, a skill, or a command.
This command dispatches nothing, so the word has no reason to appear at all.

**Check:** `bash scripts/check-commands.sh`, `bash scripts/check-patterns.sh prose commands/oneonone.md`,
and `/oneonone add test item` writes one line and prints one line.

---

### Task 5: `commands/oneonone.md`, the derivation stage

Satisfies AC 5 to 9, 45, 46, 47, 54 to 60, 66, 69 to 76, 83 to 87. Stage: derivation only. No write of
any kind may appear in this section.

**Files:** modify `commands/oneonone.md`.

- [ ] **Step 1: Config and window**

Resolve `notionParentPageId`, `timezone`, and the Jira JQL exactly as `commands/sweep.md:39-91` does,
by reference rather than by restating the resolution. Then:

```bash
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sweep-window.sh" \
  --now "$now" --state ~/.claude/polaris-memory/oneonone/state.json \
  --first-run-hours 336 --max-lookback-hours 504
```

336 is AC 6's 14-day first run, 504 is `A5`'s 21-day cap. Parse `start`, `firstRun`, `capped`,
`trueGapHours`. A non-zero exit or no JSON is a first run over 14 days, said out loud (edge-case row).
The sweep state file is never opened by this command, which is AC 8.

- [ ] **Step 2: Coverage**

```bash
d="${start%%T*}"; while [ "$d" \< "$(date -u +%F)" ]; do
  [ -f "$HOME/.claude/polaris-memory/journal/$d.md" ] || echo "$d"
  d="$(date -u -j -v+1d -f %Y-%m-%d "$d" +%F 2>/dev/null || date -u -d "$d +1 day" +%F)"
done
```

The dates it prints are the `Coverage` line in AC 9. A thin record is visible rather than read as a
quiet fortnight.

- [ ] **Step 3: Project discovery and local facts**

```bash
find "$HOME/.claude/projects" -type f -name '*.jsonl' -newermt "${start%%T*} 00:00" -print0 2>/dev/null \
  | xargs -0 -r jq -rc --arg s "$start" 'select((.timestamp // "") >= $s) | .cwd // empty' 2>/dev/null \
  | sort -u
```

The same pre-filter `scripts/journal-facts.sh:25` uses. For each distinct `cwd`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktracker-snapshot.sh" "<cwd>" "$start"
```

which prints commits, changed files, and prompts asked, or nothing at all when the project did not
move. That is the git half of the wins derivation with no new code. Also read
`<cwd>/.polaris/work/streams.md` where it exists, per D6. A `cwd` that no longer exists is skipped and
named under `Coverage` (edge-case row).

- [ ] **Step 4: The live pull, in call order**

`--offline` skips this whole step and the agenda says why the page is missing. Otherwise, in order:
`get_identity`; `list_events` over `start` to `now` plus the next 1:1; the window `list_meetings`,
paged until exhausted; the Jira JQL. Each failure is recorded as not read and the run continues
(AC 58, 59, and `rules/connectors.md`). `search_events` is not used, per AC 70.

- [ ] **Step 5: The join**

```bash
printf '%s' "<list_events json>" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/oneonone-join.sh" \
  series --self "<identity email>" --pinned "$(jq -r '.recurringEventId // ""' ~/.claude/polaris-memory/oneonone/config.json 2>/dev/null)"
```

`ambiguous` lists the candidates once, takes one answer, and writes the chosen id to `config.json`
(AC 72, and the only write that file ever takes). `none` means no series in the window: continuity
falls back to the previous agenda's `## Outcomes`, and the agenda says the series was not found.

For each instance, and only when `state.meetings["<date>"]` does not already hold it: one
`list_meetings` bracketed by that instance's `createdAfter` and `createdBefore`, then

```bash
printf '%s' "<bracketed list_meetings json>" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/oneonone-join.sh" \
  claim --attendees "<the two attendee emails>" --titles "<otherTitles, one per line>" \
        --created-after "<createdAfter>" --created-before "<createdBefore>"
```

`resolved` records the id, url, `labeled`, and `lagMinutes` into `state.meetings["<date>"]` at write
time, and the run says which id it took. `ambiguous` lists the candidates with title, duration, and
id, offers the lowest as the default, takes one answer, and persists it. `none` runs the widening
probe:

```bash
w="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/oneonone-join.sh" widen)"
```

then one `list_meetings` over `[createdAfter, instance end + w hours]`, and it reports one of two
sentences. Nothing in the widened bracket: the meeting was not recorded, the typed recap path in AC 64
takes over. Something in the widened bracket: name the id and the offset, and say that
`LAG_HOURS_DEFAULT` in `scripts/oneonone-join.sh` is too tight. Either way this branch spends no
`get_meeting_transcript`, so the probe is inside the budget.

- [ ] **Step 6: The summaries and the transcript**

At most 12 `get_meeting_summary`, chosen in AC 55's order: the previous 1:1 first, then meetings whose
participants include the manager or a client attendee, then most recent. The skipped ones are named in
a one-line `not read` note. One `get_meeting_transcript`, for the resolved previous 1:1 only. A
`recording_id` always comes from `list_meetings` and the user is never asked for one (AC 56). An empty
or truncated transcript means the meeting is treated as unrecorded for that purpose, and the run says
which recording was empty.

- [ ] **Step 7: The question budget**

Two questions on assemble, both skippable, both with a proposed default drawn from the derived set.
Zero questions when the inbox holds at least two open items and journals exist for the window (AC 45).
`--no-ask` asks nothing under any condition and writes an explicit empty line into any slot with no
content (AC 46). The disambiguation prompts in AC 72 and AC 85 are not questions under this budget:
they are one-time joins, asked once per series or per meeting date and persisted.

**Check:** run against the live connectors with `--dry-run` and count the tool calls in the
transcript. The count is the AC 54 verification and the only honest one available.

---

### Task 6: `commands/oneonone.md`, the sections and the OKR variant

Satisfies AC 10 to 27, 61, 62, 63, 67, 68, 77, 79, 80, 81, 82, plus D10's first mechanism and D11.
Stage: derivation, still no write.

**Files:** modify `commands/oneonone.md`.

- [ ] **Step 1: The nine sections, in the artifact's order**

Per reconciliation A2, `~/.claude/polaris-memory/oneonone/agendas/2026-08-05-oneonone.md` is the
format reference and AC 10 changes to match it:

1. `Wins`
2. `Top 3 they need to know`
3. `To discuss live`
4. `Forward deployment`
5. `Career and feedback`
6. `Open from last time`
7. `OKR snapshot`
8. `Status grid`
9. `Outcomes`, written by `recap` and absent until then

An item appears in exactly one section (AC 15). Caps: 5 wins each with what changed, the outcome, and
a link, with the remainder dropped rather than listed; 3 FYI lines each a sentence a manager can
repeat without opening a link; 5 live items, the rest under `Deferred to next time` and left open in
the inbox.

Every `To discuss live` item ends in a labelled `*Recommendation:*` or `*Ask:*` line, which is how the
artifact writes them and the difference is real: a recommendation is a decision the user has already
made and is reporting, an ask is a decision they need from the manager. AC 13 says "a recommendation
line" for all five, which the artifact contradicts on two of its own five items.

The order is not cosmetic. The two sections the manager answers, `Forward deployment` and
`Career and feedback`, sit above the two they only read, and the status grid is last because it is the
part nobody reads aloud. The meeting that actually happened reached the fourth and fifth sections and
nothing below them, which is the strongest possible argument for this order and against AC 10's.

- [ ] **Step 2: `Forward deployment`**

Per D11: six numbered questions directed at the manager about how the user is doing on the role's
parameters, two of them marked `priority` so a short meeting answers those first, plus prose
subsections that each close with an `Ask:`. It states no metric and repeats no KR; that is what
`OKR snapshot` is for, three sections down. This section carries no derived numbers at all.

- [ ] **Step 3: The status grid**

One row per open stream across the projects found in task 5 step 3, with state, next step, and link.
Jira is the spine and `streams.md` supplies what has no ticket, per D6. The heading carries the
artifact's wording, `Reference only, not for reading aloud`, which replaces AC 14's literal
`do not read aloud`. Same instruction, and it is the phrasing that went to a real manager.

- [ ] **Step 4: `Open from last time`, from three sources**

The previous 1:1's transcript is primary and the previous agenda's `## Outcomes` is corroboration
(AC 61). Each transcript-derived item is marked `from the recording` and written as something that was
said, never as a tracked commitment (AC 63). Where the two disagree on owner or wording, both are
shown and neither is preferred (AC 62). An action carried across three agendas is tagged
`carried · 3 meetings` (AC 26). Neither source present means the section says so and names the file it
looked for, and the run does not fail (AC 27).

The third source is D10: the previous agenda's `### Not raised` block. Those items were prepared and
never discussed, so they are listed here under a `not reached last time` marker that distinguishes
them from agreed actions, and the ones that came from the inbox are already open again because the
recap restored them, so they compete for this agenda's five live slots on their merits rather than
sitting in a continuity list nobody acts on.

- [ ] **Step 5: The unlabeled-recording rules**

A recording flagged `labeled: false` contributes content and never a speaker (AC 77), and the agenda
says so once. A feedback candidate from such a recording appears under `To confirm` or not at all, and
is never written as attributed feedback (AC 79). **No direction is proposed** (D2: AC 78 does not ship).
A Fathom action item with no assignee is written owner-unknown and never defaulted to the user; an
assigned one on an unlabeled recording is marked unreliable (AC 80). A recording flagged
`labeled: true` has its owners used as-is with no confirmation and no marker (AC 81), and the agenda
states which path each item came from.

- [ ] **Step 6: The quoting rules**

A quoted transcript line is at most one sentence and is attributed to the speaker and the recording,
so a paraphrase cannot pass as a verbatim commitment (AC 67). Anything spoken that reads as a
credential, a salary figure, or a third party's confidence is omitted (AC 68), as is a credential from
any source (AC 44). This document lands on a shared Notion page, so these are leaks and not style.
Run `bash scripts/check-patterns.sh injection <rendered agenda>` before the write as the deterministic
floor under the judgment.

- [ ] **Step 7: The OKR variant**

Due when `lastOkrCoveredAt` is 28 days old or more, per D7:

```bash
jq -r --arg n "$(date -u +%s)" '((($n|tonumber) - ((.lastOkrCoveredAt // "1970-01-01T00:00:00Z") | fromdateiso8601)) / 86400 | floor)' \
  ~/.claude/polaris-memory/oneonone/state.json
```

`--okr` forces it on, `--no-okr` forces it off (AC 18). Absent `ledger.md` means no section and
`lastOkrCoveredAt` unchanged (AC 22). Missing or unparseable `progress.json` means no section and one
line pointing at `templates/okr-progress.json`, matching `/sweep` step 1. A non-zero `okr-pace.sh` exit
means no section, the exit and the stderr line reported, and the agenda still writes.

Content: `bash scripts/okr-pace.sh --now "$now" --progress ~/.claude/polaris-memory/okr/progress.json`
unchanged. Behind KRs first, each with `needToCatch` as a number (AC 20). Every KR carries the
objective's prose title from `ledger.md` and its metric in words; no bare id such as `O1-KR2-scope`
reaches the agenda (AC 19). A disagreement between `progress.json` `current` and the sum of `log.md`
deltas is stated as both numbers and flagged, never resolved (AC 21). That case is live today:
`progress.json` has `O1-KR1` at 5 while `log.md` holds one `+1` since 2026-07-30, so the first real run
hits it. The newest file in `okr/reviews/` older than 60 days, or the directory absent, adds one line
saying to run `/sweep --okr-review` first (AC 23); the directory does not exist today, so that line
fires on run one. The calendar OKR blocks contribute intended-versus-actual hours only, and no target
or current value is ever read from an event description (AC 82). Nothing under
`~/.claude/polaris-memory/okr/` is written (AC 24).

**Check:** produce one agenda with `--dry-run` and read it against AC 10 through AC 27 by hand.

---

### Task 7: `commands/oneonone.md`, delivery and state

Satisfies AC 33 to 41, 43, 48 to 53. Stages: local write, then remote write, in that order and no
other.

**Files:** modify `commands/oneonone.md`.

- [ ] **Step 1: `--dry-run` first**

Print the rendered markdown and stop. No agenda file, no `state.json`, no inbox consume, no Notion
page (AC 36). Every step below is unreachable under `--dry-run`, and the step order in the file must
make that obvious.

- [ ] **Step 2: The edit guard, before the local write**

Per D9, AC 34 as amended:

```bash
f=~/.claude/polaris-memory/oneonone/agendas/<local-date>-oneonone.md
[ -f "$f" ] && shasum -a 256 "$f" | cut -d' ' -f1
```

Compare against `state.lastAgendaSha`. No file, or a matching hash, means write. A differing hash means
the user edited it: write nothing, print the rendered agenda to stdout, name the file left untouched,
say what is new since the last run, and stop before the inbox consume and before Notion. `--force`
writes anyway and says out loud that it discarded an edit. This is what makes
"concierge onboarding isn't built by me" a correction that survives, rather than one the next run
undoes.

- [ ] **Step 3: The local write**

`~/.claude/polaris-memory/oneonone/agendas/<local-date>-oneonone.md`, dated in the sweep config
timezone (AC 33), one file per date (AC 34 as amended by D9). Frontmatter carries `meeting`, `variant`,
`window`, `sources`, `coverage`, and the success-metric counts `derived:`, `inbox:`, `asked:`,
`calls:`. `inbox:` comes from the consume step's printed count, not from a recount. Record
`lastAgendaSha` alongside `lastRunAt` in step 8.

- [ ] **Step 4: stdout**

The full markdown, nothing withheld, so what the user reads is exactly what was written and exactly
what the page will carry (AC 35).

- [ ] **Step 5: The failure stop**

If the local write failed: `state.json` unchanged, no inbox line checked, no Notion call attempted,
and the run says it did not complete so the next run re-covers the window (AC 37, AC 39).

- [ ] **Step 6: Consume the inbox**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/oneonone-inbox.sh" consume --date "<local-date>" <the ids placed in To discuss live>
```

Only the ids that reached `To discuss live`; the rest stay `- [ ]` (AC 38, AC 40). The script refuses a
sixth id, which is the cap enforced rather than trusted.

- [ ] **Step 7: The Notion page, last**

One subpage under `notionParentPageId`, titled `1:1 — <local-date>`, carrying the same markdown that
went to stdout (AC 48). A page with that title already existing for the date is updated in place
(AC 49); the id comes from `state.lastPageId` when it is there, which costs one fetch rather than a
search. Any failure at all, including an unset `notionParentPageId`, an unreachable parent, an API
error, or a permissions refusal, is one printed line and a zero exit: `state.json` is still written,
the inbox is still consumed, and the message names the id it tried so a typo is visible rather than
read as a network problem (AC 50). `lastPageUrl` and `lastPageId` are written only on success, so a
stale id is never appended to (AC 51).

- [ ] **Step 8: `state.json`**

```json
{ "lastRunAt": "<the now from task 5 step 1>",
  "lastOkrCoveredAt": "<set only when the OKR section was written>",
  "lastAgendaSha": "<sha256 of what this run wrote>",
  "lastPageUrl": "<on success only>",
  "lastPageId": "<on success only>",
  "meetings": { "2026-07-22": { "recordingId": 166058462, "url": "…", "labeled": false, "lagMinutes": 47 } } }
```

`meetings` is what AC 74 and AC 75 persist, `lagMinutes` is the `A11` instrument accumulating across
runs, and `lastAgendaSha` is D9's edit guard. An unparseable `state.json` is treated as a first run
and overwritten on success, said out loud (edge-case row). A missing `lastAgendaSha` against an
existing agenda file is treated as an edit, which fails toward preserving the file.

- [ ] **Step 9: The artifact report**

One line per artifact: the local path, and either the page url or the reason there is none (AC 53).

**Check:** run once for real. Confirm the local file exists and the page url resolves. Then edit one
line of the agenda by hand and re-run: confirm the file is untouched, the hash mismatch is reported,
and no Notion call was made. Then break the Notion parent id and confirm the run still exits zero with
the local file written and no `lastPageId` recorded.

---

### Task 8: `commands/oneonone.md`, the `recap` verb

Satisfies AC 28 to 32, 52, 64, 65, plus D10. Stages: derivation, then local write, then remote write.

**Files:** modify `commands/oneonone.md`.

- [ ] **Step 1: Find the meeting and its recording**

Target today's agenda file; with none, target the most recent and name it before writing (AC 32). The
real cycle needs that branch on every run: the agenda was written for 2026-08-05 and the meeting
happened on 2026-08-07, two days late and under a different title, so `recap` targeting today's date
would find nothing on the day it is actually used.

Resolve the recording from `state.meetings["<date>"]` when it is there, else run one bracketed
`list_meetings` and one `claim`, exactly as task 5 step 5 does. The bracket keys on the calendar
instance, and a meeting moved off its calendar slot has no instance to bracket, so this path falls
through to the same ambiguous-or-none handling: list the untitled candidates in the window, offer the
lowest id, take one answer, persist it under the meeting's real date. The 2026-08-07 recording is an
untitled impromptu call, which is exactly tier B in the claiming pass.

- [ ] **Step 2: Propose, then take one correction**

With a recording: one `get_meeting_transcript`, then print a proposed `## Outcomes` block of
agreements, feedback received, and actions with an owner each, then ask one question, what to change
(AC 28). No claim about what anyone said reaches `## Outcomes` without a transcript call in this run,
and a claim that cannot be traced to a transcript line is omitted rather than inferred (AC 65). The
unlabeled rules from task 6 step 4 apply unchanged: content without speakers, feedback under
`To confirm`, no direction proposed.

Without a recording: fall back to the four questions in one batch, what was agreed, what feedback was
given, what the user owns, what the manager owns (AC 64).

- [ ] **Step 3: Build `### Not raised` and restore the inbox**

Per D10. Compare the prepared agenda's items against the transcript: every `To discuss live` item,
every `Forward deployment` question, and every `Ask:` the meeting did not reach goes into a
`### Not raised` subsection of `## Outcomes`, listed by name. Print that list with the proposed block
in step 2 and take the same one correction, because a misclassification here silently re-raises or
silently drops an item. Then, after the local write in step 4 and only then:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/oneonone-inbox.sh" restore --date "<agenda-date>" <the unraised inbox ids>
```

Derived items need no restore; they carry through `### Not raised`, which task 6 step 4 reads on the
next assemble.

- [ ] **Step 4: Write**

An empty reply writes the proposed block as-is and says it was accepted unedited. An empty reply with
no recording writes `no outcomes recorded` and reports that, rather than writing nothing (AC 29).
`## Outcomes` is appended to the dated agenda file with each action as `- [ ] <owner> · <action>`, and
the sections above it are unchanged (AC 30). An append leaves everything above it byte-identical, so
D9's edit guard does not apply here and the run updates `lastAgendaSha` to the appended file's hash.

- [ ] **Step 5: The page append, and the paste block**

With a `lastPageId` for that date, append the same `## Outcomes` block to that existing page. `recap`
never calls `notion-create-pages` under any condition, including a lookup that fails: a recap that
creates a page produces two records of one meeting, which the personas name as the worse failure. A
failed append or a missing id leaves the local file holding the outcomes and prints one line saying
the page was not updated (AC 52). Then print a paste-ready message block for the user to send to their
manager, and send nothing (AC 31). Nothing under `~/.claude/polaris-memory/okr/` is written, per D7.

**Check:** run `recap` against the 2026-08-07 recording (the 2026-08-07 recording) and compare
its proposed block against the `## Outcomes` section a human wrote from the same recording. Every line
in the proposal must trace to a transcript line, and the `### Not raised` list should come close to
the seven items the human found.

---

### Task 9: The first real run, and the two numbers it decides

Satisfies nothing on its own. It is the measurement the plan defers to.

- [ ] **Step 1: Run once, live, and record**

Count the tool calls. Record the join verdict, the `lagMinutes` written into `state.meetings`, and
whether `list_meetings` returned a readable `created` field at all.

- [ ] **Step 2: What each result changes**

| Measurement | If it comes out wrong | The one-line fix |
|---|---|---|
| The join returns `none` and the widened probe finds the recording | `L` is too tight, which is `A11` falsified | Raise `LAG_HOURS_DEFAULT` in `scripts/oneonone-join.sh`; the probe factor follows it |
| Derivation calls exceed 18 | The AC 55 summary cap is too high | Lower 12 to the number that fits; the agenda holds 5 wins and 3 FYI lines, so a thirteenth source meeting could not have changed the output anyway |
| `lagMinutes` is `null` | `created` is filterable but not readable, which is Q11's open half answered no | Nothing changes; the empty-join probe stays the only instrument, and the AC 84 extra bracketed call stays in the budget |
| `lagMinutes` is a number | Q11 answered yes | The claiming pass could become local arithmetic and the per-instance bracketed call could go, taking derivation from 18 to 17. A follow-up, not this plan |
| The join resolves on fewer than half of the first four runs | Either the AC 69 test is not matching or the meetings are not recorded | Read the `series` verdict: `none` means the calendar test, `none` from `claim` means the recording |

---

## Test seams and what each adds

The suite is at 185 assertion sites today.

| Seam | Covers | New assertions |
|---|---|---|
| `sweep-window.sh --first-run-hours` | AC 5 to 8 | 3 |
| `oneonone-join.sh series` and `claim` | AC 69 to 76, 83 to 87 | 12 |
| `oneonone-inbox.sh add`, `list`, `consume`, `restore` | AC 1 to 4, 13, 38 to 41, D10 | 14 |
| `okr-pace.sh` | AC 20 | 0, already covered |
| `check-commands.sh` | the dispatch-token constraint | 0, already runs |
| **Total** | | **29, taking the suite to about 214** |

D9's edit guard has no seam here: it is a `shasum` comparison inside `commands/oneonone.md`, and the
thing it guards is a file the suite must never touch. It is checked by hand in task 7's step 9.

**What has no shell seam, and what a human checks instead on the first real run.** The connector calls
are MCP tool calls a shell test cannot make, and `/sweep` has no test for its own pull either. So on
the first real run a human reads the produced agenda and checks:

1. The call count against the ledger above. This is the AC 54 verification.
2. That the nine sections appear in the artifact's order, that `Wins` holds at most 5, `Top 3` at most
   3, `To discuss live` at most 5 each ending in a labelled `Recommendation:` or `Ask:`, that
   `Forward deployment` holds six manager-directed questions with two marked `priority` and no metric,
   and that no item appears twice (AC 11 to 15, as amended by A2, A3, and D11).
3. That an item wrongly attributed to the user can be deleted by hand and stays deleted on the next
   run (D9), which is the correction the user already had to make once.
4. That no KR id such as `O1-KR2-scope` appears anywhere in the OKR section (AC 19), and that the
   `progress.json` versus `log.md` disagreement is stated with both numbers (AC 21).
5. That every quoted transcript line is one sentence, attributed to the recording, and that nothing
   resembling a credential, a salary figure, or a third party's confidence survived (AC 67, 68, 44).
6. That the `Career and feedback` section from the unlabeled recording proposes no speaker and no
   direction (AC 77, 79, D2).
7. That breaking `notionParentPageId` still produces the local file and a zero exit (AC 50).
8. After the meeting, that `recap` updates the existing page rather than creating a second one, and
   that its `### Not raised` list matches what the meeting actually skipped (D10).

Nothing in this list is automatable here, and pretending otherwise would be the failure `rules/core.md`
calls a workaround.

---

## Open, and deliberately not answered here

- **Q10, whether the page carries the outcomes.** The spec resolved it to yes and the argument is
  recorded there. Nothing in the code contradicts it, so it stands.
- **Q12, Slack as a second source.** Deferred, unchanged. It is the most expensive read in
  `rules/connectors.md` (a search pass plus a thread expansion per message) and the journals already
  fold Slack in per day.
- **Q11's remaining half.** Whether `created` is readable rather than only filterable. Task 9 answers
  it as a byproduct rather than as a separate measurement.
- **Q14's replacement question.** Whether the user annotates `To confirm` lines with a direction by
  hand. Four agendas answer it, and the answer decides whether AC 78 comes back in a measured shape.
- **The suppression list rejected in D9.** Remembering a deleted item by source key so it is never
  re-derived, instead of refusing to rewrite an edited file. Build it when the stdout-only path is
  measurably annoying, which means the user re-running on an edited agenda more than twice.

## ACs that change, collected

For whoever updates the spec. Each is argued above, and each is the real artifact winning over the
written criterion.

| AC | Change | Why |
|---|---|---|
| 10 | Nine sections in the artifact's order, not six in the spec's | A2, and the meeting reached sections four and five |
| 13 | Each live item ends in a labelled `Recommendation:` **or** `Ask:`, not a recommendation for all five | A2; the artifact splits its own five |
| 14 | Heading reads `Reference only, not for reading aloud` | A2; that is the wording sent to a manager |
| 34 | One file per date, rewritten only when the file still matches what the last run wrote | A4, D9 |
| 54 | Eighteen derivation calls plus two delivery calls, two budgets | D5 |
| 78 | Cut from v1 | D2 |
| 84 | Rank by invitee-set match, do not drop on invitee presence | D1 |
| new | `Forward deployment` is six manager-directed questions, two marked `priority`, no metrics | A3, D11 |
| new | Unraised items carry forward through `### Not raised` and through an inbox restore | A5, D10 |

## Next action

Start task 1. It is 3 lines of change, 3 assertions, and it is the only task that touches a shipped
command's behavior, so it should be green before anything else is written.
