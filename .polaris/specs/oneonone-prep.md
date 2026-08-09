# 1:1 preparation mode — requirements spec

Status: **design unblocked**. `Q1`, `Q2`, `Q5`, `Q11`, and `Q13` are answered: the capture surface is the
slash command, the agenda is written to Notion as well as the local file, the window is pulled live from
connectors with Fathom as the source that matters, the calendar-to-recording join runs on Fathom's
sub-day `created` filter, and the calendar OKR blocks contribute intent only. Eleven product decisions have
no answer in the request, so each is marked `A1`–`A11` inline with the call I made and what breaks if the
call is wrong. Two of them were rewritten after being measured rather than argued: `A1`, when the user asked
for the live connector pull, and `A9`, when five bracketed `list_meetings` calls showed that Fathom's
`created` is ingest time and the join has to run forward from the meeting rather than around it. `A11` names
the one number in here that rests on a single sample.

Filename note: the doc-organization rule wants `.polaris/specs/YYYY-MM-DD-<topic>-spec.md`. The task
named `.polaris/specs/oneonone-prep.md` explicitly, twice, so this file uses that path. Rename to
`2026-08-03-oneonone-prep-spec.md` if the rule wins.

## The problem, and who has it

The user has a bi-weekly 1:1 with their manager, and once a month one of those has to also cover the
OKR review. Today the agenda gets assembled from memory shortly before the meeting, which loses two
things. What happened in the two weeks since the last one is already forgotten by the time the slot
arrives, so the wins that a manager needs in order to argue a promotion upward never get said out
loud. And whatever was agreed in the previous 1:1 has no record, so nothing carries forward and the
same asks get re-raised or dropped.

Both source threads converge on one fix and it is not a template. The fix is a running capture of
things as they happen, plus a document assembled from that capture rather than from recall. Polaris
already accumulates the raw material: `~/.claude/polaris-memory/journal/` holds a written narrative
for 18 of the last 20 days, `.polaris/work/streams.md` holds the open threads per project,
`~/.claude/polaris-memory/okr/` holds the ledger and per-KR progress, and `git log` plus the GitHub
facts in `scripts/journal-facts.sh` hold what shipped. Fathom holds the rest, and it holds the part
none of the files do: the user records most meetings, in-person ones included, so what was agreed in
the last 1:1 and what they committed to in front of a client are both already recorded and nowhere
written down. The gap is not data. The gap is a document shaped for a manager's eyes and a place to
drop a thought at the moment it occurs.

Who else has it: nobody yet. This is a single-user capability for one person's manager relationship.
Multi-user shaping is a non-goal (see scope).

## The surface decision

**A new command, `/oneonone`, with three verbs on one file.** Argued against the three alternatives:

A lens on `/sweep` is the closest precedent and the wrong home. `/sweep` already carries two bolt-on
modes, `--okr-review` and `--okr-init`, and both earn their place by pulling no source and writing no
sweep page: they share the OKR files, not the pipeline. A 1:1 agenda would share the pipeline, which
sounds like reuse until you count what differs. Different window (fortnightly, not since-last-run),
different cursor (a shared cursor would make a 1:1 run blind the next morning sweep to two weeks of
Slack), different output shape, different reader, and a different page under the same parent.
`commands/sweep.md` is 325 lines and already fails the one-sentence purpose test if a third unrelated
mode lands in it. The live connector pull, added after the first draft, narrows this gap and is worth
saying out loud: the two commands now read overlapping sources. The cursor is what still decides it. Two
commands reading the same connectors on different rhythms is fine; two commands sharing one
`lastRunAt` is a bug that shows up as a sweep quietly missing a fortnight.

An extension of `/catchup` is worse. `/catchup` answers "where am I and what should I do next" in
one screen from three sources and is deliberately cheap. A 1:1 agenda is a durable dated artifact
someone else reads, which is the opposite of a throwaway briefing.

A skill does not fit either. `CONTEXT.md` defines a skill as a procedure with no lifecycle to
orchestrate, and this has a lifecycle: capture, assemble, meet, recap, carry forward.

The user's word was "mode", and `CONTEXT.md` lists `mode` as the synonym to avoid for **Command**.
The glossary already made this call. The vocabulary answer and the file-responsibility answer agree.

What the command reuses rather than rebuilds:

| Need | Reused | Change required |
|---|---|---|
| The fortnightly window | `scripts/sweep-window.sh` | add `--first-run-hours <n>`, default 24 so existing callers do not move |
| Per-KR pace | `scripts/okr-pace.sh` | none |
| What was said in a meeting | the Fathom MCP tools | none; `list_meetings` then `get_meeting_summary`, transcript for one recording |
| The local half of the fact record, and the fallback | `~/.claude/polaris-memory/journal/<date>.md` | none, read-only |
| Open threads and their next step | `.polaris/work/streams.md` per project | none, read-only |
| OKR objectives and progress | `~/.claude/polaris-memory/okr/` | none, read-only |
| The bi-monthly OKR review doc | `/sweep --okr-review` | none; the agenda links it, never re-derives it |
| Timezone, Notion parent, and the Jira JQL | the sweep config resolution in `/sweep` step 1 | none |
| How to read a connector without losing items | `rules/connectors.md` | none |
| Command validation | `scripts/check-commands.sh` | none |

One new script, `scripts/oneonone-inbox.sh`, one new state directory,
`~/.claude/polaris-memory/oneonone/`, and one small config file inside it for the manager's identity.
Nothing else is added. The source list is not reinvented: every connector this command reads is one
`/sweep` already resolves from the same user-level config, so there is no second place to configure a
source.

## Derived versus asked

This is the line the whole capability turns on. A question asked at agenda time is a question asked
of someone with twenty minutes before a meeting, so the budget is two questions on assemble and every
one of them must be skippable. The budget was three; Fathom moved a question's worth of material into
the derived column.

**Derived, never asked.** Shipped work and merged pull requests, from `git log` across the projects in
the window plus the journal entries. Streams that moved to done in `.polaris/work/streams.md`. Every
open thread with its stated next step, which is the status grid almost verbatim, ground-truthed
against the Jira JQL. Per-KR pace and the objective text, from `okr-pace.sh`, `progress.json`, and
`ledger.md`. What was decided and committed to in the window's meetings, from Fathom summaries. What was
agreed and what actions came out of the previous 1:1, from that one meeting's Fathom transcript. Which
meeting was the 1:1 and who the manager is, from the calendar structure in AC 69, so neither is ever
configured or asked. The candidate ranking for "top 3 things they need to know", which is classification
over the derived set and therefore a model job under core Rule 5.

**Derived but never asserted.** Who said what, when the recording is unlabeled. The content of an
offline 1:1 is derivable and its speakers are not, so feedback and evaluations from such a recording are
proposed for confirmation and never written as attributed (AC 77 to 79). This is a third column on
purpose: collapsing it into "derived" is how the user ends up reading their own words back as their manager's
feedback.

**Asked, and only when derivation leaves the slot empty.** Anything about bandwidth or how the work
feels, which exists nowhere and in no recording. The career ask for this cycle, when the inbox holds
nothing for it. Both have a proposed default drawn from the derived set, so an empty answer still
produces a usable line rather than a hole.

**Captured, so it is neither derived nor asked at meeting time.** Everything the user thought of
during the two weeks, appended one line at a time to `inbox.md`. This is the load-bearing part. If
capture does not happen the mode degrades to a status report, which is the failure the threads warn
about.

`A1` (rewritten): the window is read live from Fathom, Google Calendar, and Jira, and the written
journal entries are the fallback and the cross-check rather than the primary. The user records most
meetings with Fathom, including the in-person ones, so the recordings hold the two things that exist
nowhere else on disk: what was said in the last 1:1, and what they committed to in front of a client.
No amount of reading `~/.claude/polaris-memory/journal/` recovers a spoken agreement. Cost: the
assembly path now makes network calls, which is exactly what `A1` originally existed to prevent.
Three things keep the rushed persona alive rather than one flag: the call budget in AC 54, the
degradation rule in AC 58 that produces the agenda from journals and streams when a source is
unreachable, and `--offline` in AC 60 as a chosen fast path rather than an accident. Journals stay in
the read set because they cover a day spent in Slack with no meeting and no commit, which Fathom
cannot see.

`A8`: three live sources in v1, not eight. "All connectors" is a direction, and a first run that
takes four minutes gets abandoned once and never retried, which costs more than a missing source.
Each source clears the same bar: what does it add to a manager-facing agenda that the journal
narrative does not already carry?

| Source | v1 | Why |
|---|---|---|
| Fathom | in | Spoken agreements, feedback, and client commitments exist in no other store. The only source that changes what the document can contain |
| Google Calendar | in | One `list_events` call gives the next 1:1's date, which sets the date the agenda is written for and the day-ahead send moment |
| Jira | in | One JQL call ground-truths the status grid against real issue status instead of an agent's summary of it. The first source I would cut if the run feels slow |
| Slack | deferred | The most expensive read in Polaris: `rules/connectors.md` requires a search pass plus a thread expansion per message. Journals already fold Slack in per day, and a manager agenda gains little from raw channel traffic |
| Gmail | deferred | Almost nothing reaches a manager-facing agenda that the journal does not carry |
| GitHub | deferred | Already covered by `git log` and the GitHub facts in `scripts/journal-facts.sh` |
| Linear, Sentry, Confluence | deferred | Not in the user's stated workflow for this meeting; no evidence they hold agenda material |
| Notion | write only | It is the delivery target, not a source |

## Requirements

Criteria are cited by the number written beside them, and the numbers are not resequenced when a review
adds one. R11 to R13 were appended after three rounds of answers, so a section can run 25, 26, 27, then
61, and a citation to AC 61 stays valid forever. Read the numbers as identifiers, not as positions.

### R1 — capture an item in one line, any time

1. Given `~/.claude/polaris-memory/oneonone/` does not exist, when the user runs `/oneonone add ask
   about the promotion rubric`, then the directory and `inbox.md` are created and the file ends with
   `- [ ] 2026-08-03 · ask about the promotion rubric`, and the command prints one line naming the
   file and the item count.
2. Given `inbox.md` holds 3 open items, when the user adds a fourth, then the file holds 4 items in
   append order and no existing line is rewritten.
3. Given the user runs `/oneonone add` with no text, then nothing is written and the command prints
   `oneonone add: nothing to add; pass the item text`.
4. Given the item text contains a newline, then it is stored as one line with the newline collapsed
   to a space, so the item count stays equal to the line count.

### R2 — assemble the agenda from the window

5. Given the last run was 14 days ago and `--now` is 2026-08-03, when the user runs `/oneonone`, then
   the window passed to every reader is `lastRunAt` to now, computed by `sweep-window.sh` with
   `--state ~/.claude/polaris-memory/oneonone/state.json`, and not by date arithmetic in prose.
6. Given no `oneonone/state.json` exists, when the user runs `/oneonone`, then the window is the last
   14 days and the agenda says it covers the last 14 days as a first run.
7. Given the last run was 40 days ago and the cap is 21 days, then the window starts 21 days back and
   the agenda states the true gap in days.
8. Given `/oneonone` has just run, then `~/.claude/polaris-memory/sweep/state.json` is byte-identical
   to what it was before the run.
9. Given the window covers 14 days and journal entries exist for 12 of them, then the agenda names
   the two dates with no entry under a `Coverage` line, so a thin record is visible rather than read
   as a quiet fortnight.

### R3 — the five sections, in the video's order

10. Given a run with derived material, when the agenda is written, then its sections appear in this
    order and no other: `Wins`, `Top 3 they need to know`, `To discuss live`, `Career and feedback`,
    `Status grid (do not read aloud)`, `Open from last time`.
11. Given the window contains 9 merged pull requests and 2 streams that closed, then `Wins` lists at
    most 5 entries, each with what changed, the outcome it produced, and a link, and the remainder are
    dropped rather than listed, because a 5-item win list is a spoken list.
12. Given `Top 3 they need to know` is rendered, then it holds at most 3 entries and each is one
    sentence a manager can repeat to their own manager without opening a link.
13. Given the inbox holds 12 open items, then `To discuss live` holds at most 5 of them, each with a
    recommendation line, and the rest appear under `Deferred to next time` and stay open in the inbox.
14. Given a run at all, then `Status grid` is a table of every open stream across the projects seen in
    the window, one row per stream with its state, its next step, and a link, and the section carries
    the literal heading text `do not read aloud`.
15. Given an item was placed in a section, then the same item appears in exactly one section.

### R4 — the monthly OKR variant

16. Given `lastOkrCoveredAt` in state is 31 days old, when the user runs `/oneonone`, then the agenda
    includes an `OKR review` section and the run reports that it is treating this as the monthly one.
17. Given `lastOkrCoveredAt` is 14 days old, then no `OKR review` section is written.
18. Given `--okr` is passed while `lastOkrCoveredAt` is 14 days old, then the section is written
    anyway; given `--no-okr` is passed while it is 31 days old, then it is not.
19. Given the OKR section is written, then each KR appears with the objective's prose title from
    `ledger.md` and the metric in words, and no bare id such as `O1-KR2-scope` reaches the agenda,
    because the reader is a manager who has never seen the id scheme.
20. Given `okr-pace.sh` reports `O2-KR1` behind by 1, then that KR is listed first with its
    `needToCatch` value stated as a number.
21. Given `progress.json` records `current: 4` for `O1-KR1` while the deltas in `log.md` sum to 0,
    then the section states both numbers and flags the mismatch, and the agenda does not silently
    pick one. This is the state on disk today, so the first real run hits it.
22. Given `~/.claude/polaris-memory/okr/ledger.md` is absent, then the agenda is produced with no OKR
    section, and `lastOkrCoveredAt` is left unchanged.
23. Given the newest file in `~/.claude/polaris-memory/okr/reviews/` is older than 60 days or the
    directory is empty, then the OKR section links no review and adds one line telling the user to run
    `/sweep --okr-review` first.
24. Given the OKR section was written, then no file under `~/.claude/polaris-memory/okr/` was modified
    by this run.

### R5 — continuity between meetings

Continuity has two sources now, and the transcript is the stronger one. The success metric already
predicted the recap is the step most likely to lapse, and a derived continuity section survives a user
who never runs `/oneonone recap` at all. So the previous 1:1's transcript is the primary and the
previous agenda's `## Outcomes` is the corroboration.

25. Given the previous agenda file has an `## Outcomes` section with 2 unchecked actions, then the new
    agenda's `Open from last time` lists both with the date they were agreed.
26. Given an open action has carried across 3 agendas, then it is tagged `carried · 3 meetings` so a
    thing that keeps not happening is visible.
27. Given the previous agenda file has no `## Outcomes` section and no Fathom recording of the previous
    1:1 was found, then `Open from last time` says the previous meeting has no record and names the
    file it looked for, and the run does not fail.
61. Given the previous 1:1 was found in Fathom, then `Open from last time` is built from its transcript
    and each item is marked `from the recording`, whether or not a recap was ever run.
62. Given both the transcript and the previous agenda's `## Outcomes` carry an action and they disagree
    on the owner or the wording, then both versions are shown and neither is silently preferred.
63. Given an action derived from a transcript, then it is written as something that was said, never as
    a tracked commitment, because `rules/connectors.md` already holds that a transcript claim is not
    proof a ticket exists.

### R6 — the recap, as propose-and-correct

The interview is gone. The command proposes what the recording holds and the user corrects it, which
is a shorter interaction and survives a user who forgets what was agreed. What it proposes depends on
which kind of recording it read: a labeled one gives owners that can be trusted (AC 81), an unlabeled one
gives content with no reliable speaker (AC 77 to 80), and the correction step is where the second kind
earns its confirmation.

28. Given a Fathom recording exists for the 1:1 that just happened, when the user runs `/oneonone
    recap`, then the command reads that transcript and prints a proposed `## Outcomes` block
    (agreements, feedback received, actions with an owner each), then asks one question: what to change.
29. Given the reply is empty, then the proposed block is written as-is and the command says it was
    accepted unedited. Given no recording was found and the reply is empty, then `## Outcomes` is
    written with `no outcomes recorded` and the run reports that, rather than writing nothing.
30. Given answers were given, then `## Outcomes` is appended to that dated agenda file with each
    action as `- [ ] <owner> · <action>`, and the pre-existing sections above it are unchanged.
31. Given the recap is written, then the command prints a paste-ready message block for the user to
    send to their manager, and sends nothing itself.
32. Given `/oneonone recap` runs with no agenda file for today, then it targets the most recent agenda
    file and names it before writing.
64. Given no recording is found for the meeting, then the command falls back to asking the four
    original questions in one batch (what was agreed, what feedback was given, what the user owns, what
    the manager owns), because not every 1:1 gets recorded.
65. Given a recording was found, then no claim about what anyone said reaches `## Outcomes` without a
    `get_meeting_transcript` call in this run, and a claim that cannot be traced to a transcript line
    is omitted rather than inferred.

### R7 — the output and its delivery

33. Given a successful run on 2026-08-03, then the agenda is at
    `~/.claude/polaris-memory/oneonone/agendas/2026-08-03-oneonone.md`, dated in the sweep
    config timezone.
34. Given `/oneonone` runs twice on the same day, then the second run rewrites that one file and no
    second file for the date exists.
35. Given a successful run, then the full agenda markdown is printed to stdout with nothing withheld,
    so what the user reads is exactly what was written and exactly what the page will carry.
36. Given `--dry-run`, then the agenda is printed and none of the agenda file, `state.json`,
    `inbox.md`, or a Notion page is written.
37. Given the agenda file write fails, then `state.json` is left unchanged, no Notion page is
    attempted, and the command says the run did not complete, so the next run re-covers the same
    window.
48. Given the local agenda file and the stdout output are both written, then and only then is a Notion
    subpage created under `notionParentPageId` (resolved exactly as `/sweep` step 1 resolves it),
    titled `1:1 — <local-date>`, dated in the sweep config timezone, carrying the same markdown that
    went to stdout.
49. Given a page titled `1:1 — 2026-08-03` already exists under that parent, when a second run happens
    on 2026-08-03, then that page is updated in place and no second page for the date is created,
    matching AC 34's one-artifact-per-date rule on both sides.
50. Given the Notion write fails for any reason (no network, `notionParentPageId` unset, the parent
    unreachable, an API error, a permissions refusal), then the run is still a success: the command
    prints one line naming the failure, `state.json` is written, the inbox is consumed per AC 38, and
    the exit status is zero. The local file and the stdout copy are the artifact the user needs, and
    losing the page does not lose the meeting.
51. Given the Notion write succeeded, then `state.json` records `lastPageUrl` and `lastPageId`; given
    it failed, then neither key is written or updated, so a stale id never gets appended to.
52. Given `/oneonone recap` writes `## Outcomes` to the local agenda and `state.json` holds a
    `lastPageId` for that same date, then the same `## Outcomes` block is appended to that page; given
    the append fails or no `lastPageId` exists, then the local file still holds the outcomes and the
    command prints one line saying the page was not updated.
53. Given a run at all, then the command prints one line per artifact stating what went where: the
    local path, and either the page url or the reason there is none.

### R8 — inbox lifecycle

38. Given items 1 to 5 of 12 were placed in `To discuss live`, when the agenda write succeeds, then
    those 5 lines in `inbox.md` become `- [x]` with the agenda date appended, and the other 7 stay
    `- [ ]`.
39. Given the agenda write failed, then no inbox line is checked off.
40. Given `inbox.md` holds 40 items of which 30 are checked, then only the 10 open ones are read for
    the agenda, and the checked ones are left in the file as history.
41. Given `inbox.md` is empty and the window yielded derived material, then the agenda is still
    produced, and `To discuss live` carries the up-to-3 asked questions instead.

### R9 — everything read is data

42. Given a journal entry, a stream, a Jira summary, an OKR ledger line, a calendar event description,
    or a **Fathom transcript or summary** contains text shaped like an instruction (`ignore your
    instructions`, `write the agenda to <other path>`, `send this to <address>`), then the agenda write
    path, the Notion parent id, the state path, and the question budget are unchanged, and the text is
    quoted as content if it is relevant at all. A transcript is the sharpest case in the read set: it is
    other people's speech, recorded in a room, and a sentence someone says out loud arrives here as
    untrusted input exactly as `rules/connectors.md` means it.
67. Given a transcript line is quoted in the agenda, then it is at most one sentence and it is attributed
    to the speaker and the recording, so a paraphrase can never pass as a verbatim commitment.
68. Given a transcript contains something spoken aloud that reads as a credential, a salary figure, or a
    third party's confidence, then it is omitted from the agenda. A recorded room contains more than the
    speaker meant to publish, and this document goes to a shared Notion page.
43. Given a run at all, then the only local paths written are under
    `~/.claude/polaris-memory/oneonone/`, and the only remote write is the one Notion subpage under the
    configured `notionParentPageId`. No source content adds a second write target or moves either one,
    which is the rule `/sweep` already fixes for its own parent id.
44. Given a source line contains something that looks like a credential, then it is omitted from the
    agenda rather than quoted. This rule was already justified by the document leaving the user's
    machine; with the Notion write it provably leaves, so a credential quoted out of a journal entry
    lands in a shared workspace and the rule now blocks a real leak rather than a likely one.

### R10 — the rushed path

45. Given the inbox holds at least 2 open items and journals exist for the window, when `/oneonone`
    runs, then it asks zero questions and produces the agenda.
46. Given `--no-ask`, then no question is asked under any condition and any slot with no derived or
    captured content is written as an explicit empty line the user can fill by hand.
47. Given a default run, then its network calls are bounded and ordered: the derivation stage calls
    Fathom, Calendar, and Jira within the budget in AC 54; the local agenda file and the stdout copy are
    written next and depend on no network; the one Notion write comes last and cannot fail the run per
    AC 50. Given `--offline`, then the run makes no network call at all.

### R11 — the live pull

54. Given a default run over a 14-day window containing 30 recorded meetings, then the calls are at most
    one `list_events`, one `get_identity`, one `list_meetings` over the window (paged until exhausted), one
    further `list_meetings` per manager 1:1 instance for the forward bracket in AC 73, 12
    `get_meeting_summary`, one `get_meeting_transcript`, and one Jira JQL: eighteen plus paging for the
    single-instance case, nineteen when a fortnight holds two instances. The join costs one call, not one
    per calendar event, because only the 1:1 needs a time join at all; the 12 summaries that feed the wins
    need no bracket. The summary cap is 12 because the agenda holds at most 5 wins and 3 FYI lines, so a
    thirteenth source meeting cannot change the output. A run exceeding the budget is a regression, the way
    an over-count of agents is in the review levels.
55. Given more than 12 meetings in the window, then the 12 summarized are chosen in this order: the
    previous 1:1 first, then meetings whose participants include the manager or a client attendee, then
    most recent. The remainder are named in a one-line `not read` note so the user sees what was skipped.
56. Given a `recording_id` is needed, then it comes from `list_meetings`, and the user is never asked
    for one. This is the Fathom server's own constraint and it is a hard rule here.
57. Given a run at all, then the manager is derived, never configured: the command calls `get_identity`
    for the user's own address and takes the manager to be the one non-self attendee of the manager 1:1
    series found per AC 69. No `manager` key is asked for on a first run.
58. Given Fathom is unreachable, unauthenticated, or returns no meetings in the window, then the agenda
    is still produced from journals, streams, git, and the inbox; the run reports which sources were
    reached and which were not; and no section is silently thinned without saying so. The same holds
    for Calendar and Jira independently.
59. Given a source failed, then every item that source would have contributed is absent rather than
    guessed, and the agenda carries a `sources not read` line naming it, matching what
    `rules/connectors.md` requires of every Polaris connector read.
60. Given `--offline`, then no connector is called and no Notion page is written, the agenda is built
    from journals, streams, git, and the inbox, and the output says why the page is missing.
66. Given the previous 1:1 is being identified, then it is identified through the calendar first and
    Fathom second, per AC 69 and AC 73. Fathom participant lists are not the primary signal, because the
    observed recording of the 2026-07-22 1:1 carries no `calendar_invitees` at all and would never have
    matched on participants.

### R12 — finding the 1:1 through the calendar

The identification chain is calendar event, then recording, then transcript. Every fact below was
observed in the live connectors over 2026-07-20 to 2026-08-04, not assumed. The join from event to
recording is the part that took two attempts, and the second one exists because the first was measured and
failed: `created` on a Fathom meeting is when the recording reached Fathom, not when the meeting started.

69. Given `list_events` over the window, then a manager 1:1 instance is an event with a
    `recurringEventId`, exactly two attendees, one of which is `self`. The other attendee is the manager.
    The observed instance is `1:1 Manager / Self`, 2026-07-22 16:00 to 16:30 `Asia/Kolkata`,
    `recurringEventId: da2d2380871a4f3da1c1f23f3e1ce03b`, attendees `manager@example.com` and self, so
    the manager resolves to Manager Example without a config value.
70. Given the calendar is read, then it is read with `list_events` over an explicit `startTime` and
    `endTime`. `search_events` is not used: the semantic query `1:1 one-on-one with manager` returned an
    empty object against a window that provably contains the event, so a design built on it would find
    nothing and report an unrecorded meeting.
71. Given two or more events in the window match AC 69's structural test, then the title is the
    tiebreaker and a title containing `1:1` or `one-on-one` wins. Given the tie survives that, then AC 72
    applies. A title is a convention that can be renamed; two attendees plus recurring is a structural
    fact, so the structure decides first and the words only break ties.
72. Given more than one candidate series remains after AC 71, then the candidates are listed once, the
    user picks one, and the chosen `recurringEventId` is written to
    `~/.claude/polaris-memory/oneonone/config.json` and never asked again. This is the only case that
    writes that file.
73. Given a manager 1:1 instance from 2026-07-22T10:30:00Z to 11:00:00Z, then its candidate recordings
    come from one `list_meetings` bracketed **forward from the event**:
    `created_after = <event start>`, `created_before = <event end + L>`, with `L` the ingest-lag bound in
    AC 83. The window runs forward because `created` is Fathom's ingest time, not the meeting start: an
    offline recording uploads and processes after the meeting ends, so at the event's end the recording does
    not exist yet. The earlier draft of this criterion bracketed `[event start − 10 minutes, event end]` and
    could never have matched anything. The measurement that killed it: `10:20Z`–`11:10Z`, which brackets the
    event, returns zero meetings, while `11:10Z`–`12:30Z` returns the 1:1's recording `166058462` alone.
    Anyone who reads `created` as a start time will reintroduce this bug, so the direction is part of the
    criterion, not a note beside it.
83. Given the lag bound `L`, then `L` is **3 hours, provisional**. One sample supports it: the recording of
    a meeting that ended at 11:00Z has a `created` between 11:40Z and 12:30Z, so 40 to 90 minutes of lag.
    One sample is not a distribution and this spec does not present it as one; 3 hours is that sample with
    room, not a measured ceiling. What falsifies it: any 1:1 whose recording is absent from
    `[event start, event end + 3h]` and present in a wider bracket. The mode reports every empty join
    (AC 86), so a too-tight bound shows up as a run that found no recording for a meeting the user knows
    was recorded, and the fix is to widen `L` or to key the join on a real ingest timestamp if Fathom ever
    exposes one per recording.
84. Given the candidate set from AC 73, then it is narrowed by claiming, not by searching each event in
    isolation. Drop every candidate carrying `calendar_invitees`, since a scheduled meeting is not the
    in-person 1:1 and this alone removes the SAGE Syncs and the Stand Ups. Then drop every candidate that
    another calendar event in the window explains better, matching on title. What remains is the unclaimed
    set for this event.
85. Given exactly one unclaimed candidate, then it is the recording and the run says which id it took.
    Given more than one, then the run picks nothing on its own: the candidates are listed with title,
    duration, and id, ordered by id ascending, the lowest offered as the default so the answer is one
    keystroke, and the choice is persisted per AC 75. A silent pick here attributes another meeting's
    content to the 1:1, which is worse than an empty section because it is wrong rather than missing, and
    2026-07-31 already holds two `Impromptu Call` recordings, so the ambiguity is real and not theoretical.
86. Given zero candidates, then the meeting is reported as unrecorded and the report names the bracket it
    searched, so a too-tight `L` is distinguishable from a meeting nobody recorded. The typed recap path in
    AC 64 takes over.
87. Given recording ids are used, then they are used for display order and as the offered default in
    AC 85, never as the sole basis for an automatic attribution. The ordering is observed rather than
    documented: `166058462` for the 10:30Z 1:1 sorts below `166154353` for the same day's 15:00Z SAGE
    Sync, and the ordering held across all 13 meetings in the fortnight. It is an implementation detail of
    someone else's id generator, so a criterion that depended on it would rest on a promise Fathom never
    made.
74. Given the join was resolved by a user pick per AC 85, then it is asked once for that meeting date and
    never again, because AC 75 persists it.
75. Given a recording has been resolved for a meeting date, then `state.json` records
    `meetings: { "<date>": { "recordingId": ..., "url": ..., "labeled": true|false } }`, and later runs
    reuse it rather than re-running the join.
76. Given a Fathom meeting has no `calendar_invitees`, then it is flagged `labeled: false` by that test
    alone. The test is a field presence check, so code decides it and no model judgment enters (core Rule
    5). Every observed `Impromptu Call` lacks the field while the SAGE Syncs and Stand Ups carry it, and
    the offline 1:1 is an `Impromptu Call`.

### R13 — an unlabeled recording says what was said, not who said it

Fathom does no speaker recognition on an in-person recording, and the data shows what that produces:
every assigned action item on an `Impromptu Call` goes to Abhishek Sharma, while on the calendar meetings
they spread across four named participants. The offline 1:1 is exactly the
case where attribution matters most and is least available. No heuristic recovers it, and this spec does
not pretend one does.

77. Given a recording is flagged `labeled: false`, then no line drawn from its transcript is written as a
    statement about who said something. Attribution is not recoverable from that recording and the agenda
    says so once, in one line, rather than implying the mapping was solved.
78. Given a transcript line from an unlabeled recording carries a second-person imperative or evaluation
    (`you should focus on`, `I'd like to see you`), then it is proposed as something said to the user;
    given a first-person commitment (`I'll have it by Friday`), then it is proposed as the user's own.
    Both are proposals, both are marked `confirm`, and grammar-derived direction is never written as
    settled.
79. Given a candidate line for `Career and feedback` comes from an unlabeled recording, then it is not
    written as attributed feedback unless the user confirms it in that run. Unconfirmed, it appears under
    `To confirm` or not at all. The failure this blocks is specific and bad: the user's own words handed
    back to them as their manager's feedback, inside a document they then send to that manager.
80. Given a Fathom action item has no assignee, then it is written owner-unknown, never defaulted to the
    user. The observed 1:1 recording has exactly one action item, `Update Sage OKRs per 3-part framework;
    send to Abhishek for approval`, with no assignee, and Fathom leaving it blank is information. Given an
    action item is assigned on an unlabeled recording, then it is written with its assignment marked
    unreliable, because on those recordings every assignment lands on the recorder.
81. Given a recording is flagged `labeled: true`, then its action items and their owners are used as-is,
    with no confirmation step and no unreliability marker. The two paths differ, and the agenda states
    which path each item came from.
82. Given the calendar contains the recurring OKR blocks (`Forward deployment · O1`,
    `Delivery Excellence · O2`, `Case study · O3`, `Delivery Health · O4`, `Weekly review + plan`), then
    the OKR section may state intended-versus-actual: hours blocked against an objective in the window
    beside the movement `progress.json` recorded for it. Targets and current values are never read from an
    event description, even though the O1 block's description states "8 found and fixed, 8 suggestions
    accepted (4+ changing scope), 4 strategic decisions shaped". `ledger.md` and `progress.json` stay the
    single source of truth for what the numbers are; the calendar only says where the time went.

## Testing seams

Confirm these before design. Three of the four already exist, which is the point.

- `scripts/oneonone-inbox.sh add|list|consume` — the one new seam, and the reason it exists is that
  the whole capture and consume path is otherwise only reachable through a model, which this repo's
  shell test suite cannot assert on. Covers AC 1 to 4 and 38 to 41.
- `scripts/sweep-window.sh --state <path> --first-run-hours <n>` — covers AC 5 to 8. The existing
  suite already has cases for this script; the new flag adds cases beside them.
- `scripts/okr-pace.sh` — unchanged, covers AC 20.
- `scripts/check-commands.sh` — covers the command file's frontmatter, as for every other command.

Everything else is prose behavior inside `commands/oneonone.md` and is checked by reading the
produced agenda, the same way `/sweep`'s output is. The live pull has no shell seam and gets none: the
connector calls are MCP tool calls a shell test cannot make, and `/sweep` already has no test for its
own pull. The call budget in AC 54 is verified by counting the tool calls in one real run, which is the
only honest check available and is the same evidence the review-level agent counts rest on.

Two of the new rules are pure field predicates over connector JSON rather than judgment: the 1:1 test in
AC 69 (a `recurringEventId` plus two attendees, one `self`) and the unlabeled test in AC 76 (`calendar_invitees`
absent). If a seam for them is wanted, both belong in one small script reading the JSON on stdin, which
would make them testable from fixtures captured off one real run. I am not specifying that script as
required, because a `jq` expression inside the command is smaller and the two predicates are three lines
each. Add it the moment either predicate grows a third condition.

## Scope

**v1 does:** capture a one-line item any time; pull the window live from Fathom, Calendar, and Jira,
with journals, streams, git, and the inbox as the local half; find the 1:1 and the manager from the
calendar's structure and join that interval to the Fathom recording; assemble a dated agenda; add the OKR
section on the monthly cadence; derive what was agreed from the previous 1:1's recording, marking
anything from an unlabeled recording for confirmation; carry open actions forward; write the agenda to a
Notion subpage under the same `notionParentPageId` `/sweep` uses; propose the recap from the recording for
the user to correct; print everything it wrote and where.

**v1 does not:**

- Send anything. No email, no Slack post, no calendar edit. The Notion page is a write, not a send, and
  it fires no notification; the user still tells their manager it is there.
- Add a `--no-notion` flag. AC 50 already makes a failed page write a non-event, and `--offline`
  already covers the deliberate no-network run. A third way to say the same thing is one flag too many.
- Read Slack, Gmail, Linear, Sentry, or Confluence live. See `A8` for the bar each failed.
- Track a promotion rubric. No rubric data model, no per-category progress, no level definitions. The
  career slot carries a rubric ask forward as an inbox item and nothing more.
- Write to `~/.claude/polaris-memory/okr/`. The OKR section is read-only. `/sweep`'s evening block
  owns progress writes and `--okr-review` owns the review doc.
- Ask for the manager, or hold a manager in config. The calendar's structure gives it (AC 69). The only
  thing ever written to `config.json` is a chosen `recurringEventId` when two candidate series tie.
- Handle a second manager, a skip-level, a peer 1:1, or a 1:1 the user runs as the manager. One series,
  one manager.
- Recover speaker attribution on an in-person recording, or ship a heuristic that pretends to. Fathom does
  no speaker recognition there, grammar gives direction and nothing more, and AC 77 to 79 keep the
  uncertainty on the page instead of hiding it.
- Use `search_events`. It returned an empty object for a window that contains the event (AC 70).
- Read OKR targets or progress from a calendar event description. The blocks say where time went, not what
  the numbers are (AC 82).
- Fire on a schedule. The user runs the command. Calendar is read for the next 1:1's date, not to
  trigger anything.
- Record or transcribe anything. Fathom already records; this reads what Fathom has.
- Score or grade anything. No self-rating, no readiness percentage.

## Persona findings

**Rushed Tuesday, meeting in twenty minutes.** The one that shaped the design most, and the one the
live pull threatens. It still holds, and it now costs four things rather than one: the zero-question
default path (AC 45), `--no-ask` (AC 46), the hard call budget of sixteen calls plus paging (AC 54), the
degradation rule that produces a full agenda when a source is unreachable (AC 58), and `--offline` as
a chosen fast path (AC 60). The ordering matters as much as the budget: the local file and the stdout
copy are written before the Notion call, so a slow or dead network delays nothing the user needs. If a
default run ever needs a connector round trip it cannot skip, or an interview, this persona abandons
the mode and the whole thing dies.

**The manager reading it the evening before.** Forced AC 19: KR ids are internal vocabulary and a
manager reading `O1-KR2-scope` learns nothing. Forced AC 12, one repeatable sentence per FYI item, and
AC 14, the status grid as a table with links so it is self-serve. Forced AC 44 and now AC 68: this
document leaves the user's machine and lands on a shared Notion page, so a credential in a journal
entry or a salary figure spoken aloud in a recorded room is a real leak. Also forced AC 52's argument:
the manager who read the page before the meeting should find the outcomes on the same page after it,
not in a private file. And this is the persona that makes AC 79 non-negotiable rather than pedantic. The manager
opening a page that quotes them saying something they never said, which is in fact Abhishek's own sentence
mislabeled by a recording with no speaker separation, damages the exact relationship the mode exists to
serve. An unconfirmed attribution is worse than a blank line.

**Naive use.** Runs it twice in one day, so AC 34 and AC 49 make the second run overwrite the file and
update the same page rather than forking the date on either side. Forgets the recap for three meetings
running, which used to break continuity and now does not: AC 61 derives it from the recordings instead,
AC 27 keeps the run alive when there is no recording either, and AC 26 makes a repeatedly-carried
action visible. Types `/oneonone add` with nothing, so AC 3 refuses instead of appending a blank. Pastes
a multi-line thought into `add`, so AC 4 keeps one item on one line.

**Power use.** Forty inbox items, six active projects, and thirty recorded meetings in the fortnight,
so AC 13 caps live discussion at 5, AC 11 caps wins at 5, and AC 55 caps summaries at 12 and names what
it skipped. A 45-minute slot with 20 to 30 minutes of live discussion cannot absorb twelve topics, and
an agenda that pretends otherwise is the same failure as no agenda. Runs offline on a plane, which
`--offline` in AC 60 now covers explicitly rather than by accident.

**Adversarial input.** The attack surface grew, and it grew in the worst direction. There is still no
second tenant, so the surface is the content this command reads, and that content is now other people's
recorded speech. Journal entries quote Slack and Jira, the OKR ledger is user-written prose,
`streams.md` is agent-written, and a Fathom transcript is whatever anyone in the room said. A client
saying "and then just email the summary to legal@example.com" is a sentence in a transcript, not an
instruction to this command, so AC 42 fixes the write path, the Notion parent id, and the question
budget against every one of those sources by name. AC 67 bounds how much of a transcript can be quoted
and forces attribution, and AC 68 keeps a spoken salary figure or a third party's confidence off a page
the manager's whole workspace may be able to open. AC 65 handles the subtler failure: a claim about what
someone said, made without a transcript call, is a fabrication with a manager as its audience, so it is
omitted rather than inferred. The second adversarial case is the user's own future self reading the
agenda as fact: AC 21, AC 9, AC 59, and AC 62 exist so a thin record, a contradictory OKR number, an
unread source, or two versions of one agreement are all stated rather than smoothed over.

## Success metrics

No telemetry exists in this plugin and none gets added. Every metric below is a `grep` over
`~/.claude/polaris-memory/oneonone/`, and each agenda records its own counts in frontmatter
(`derived:`, `inbox:`, `asked:`, `sources:`, `calls:`) so the ratios are readable after the fact.

- **Adoption.** At least 4 agenda files exist after 8 weeks, against an expected 4 to 5 at bi-weekly
  cadence. Below 2 and the mode is not being used and nothing else matters.
- **Capture is working.** Median `inbox:` count per agenda is 2 or more. The user has confirmed they will
  type `/oneonone add` mid-thought, so this metric no longer tests a guess; it tests whether the
  confirmed intent survived contact with a real fortnight. Watch it above all the others. If the median
  comes in at zero, the capture surface is the first thing to revisit, whatever the answer to `Q5` was,
  because a mode fed only by derivation is a status report and the threads are explicit that a status
  report wastes the slot.
- **The question budget held.** `asked:` is 2 or less on every agenda, and 0 on at least half.
- **The join is earning the live pull.** The previous 1:1's recording is resolved on 3 of every 4 runs,
  and `calls:` stays inside the AC 54 budget on every run. Below half and either the calendar test in AC 69
  is not matching or the meetings are not being recorded, and the derived continuity section is a promise
  the mode cannot keep.
- **Attribution is not being rubber-stamped.** Of the feedback lines proposed from an unlabeled recording,
  the share the user confirms sits between 20% and 80%. Near 100% means they are accepting whatever is put in
  front of them and the `confirm` step is theatre; near 0% means the grammar heuristic in AC 78 is noise and
  `Q14` should cut it.
- **Continuity is real.** Of the actions written into an `## Outcomes` section, 60% or more are
  checked off or absent from the next agenda within two meetings. A number near zero means the outcomes
  section is a diary, not a tracker.
- **The record exists at all.** At least 3 of every 4 agenda files have an `## Outcomes` section, from
  a run of `/oneonone recap` or derived from the recording per AC 61. This target used to measure recap
  discipline and now measures coverage, which is the thing that actually matters and no longer depends
  on the user remembering a second command.

The baseline for all six is zero, because none of this is recorded anywhere today.

## Edge cases and error states

| Condition | Behavior |
|---|---|
| No journal entry anywhere in the window | Produce the agenda from the inbox, streams, and git alone; state that the journal record is empty for the window |
| `oneonone/` absent on a read verb | Create nothing, say the inbox is empty, produce the agenda from derived material |
| `inbox.md` present but a line does not match the item format | Read the lines that parse, list the ones that did not with their line numbers, write nothing back to them |
| `progress.json` missing or unparseable while `ledger.md` exists | No OKR section; one line pointing at `templates/okr-progress.json`, matching what `/sweep` step 1 already does |
| `okr-pace.sh` exits non-zero | No OKR section; report the exit and the stderr line; the agenda still writes |
| `sweep-window.sh` exits non-zero or prints no JSON | Treat as a first run over 14 days and say so; never proceed without a window |
| A project directory in a journal entry no longer exists | Skip it, name it under `Coverage`, keep going |
| Two runs on the same date | The second rewrites the one dated file (AC 34) |
| `state.json` unparseable | Treat as a first run, overwrite it on success, say what happened |
| Zero derived material and an empty inbox | Write the agenda with every section present and explicitly empty, plus one line saying there is nothing to report from the window. A missing file reads as a missed meeting |
| Agenda write fails after the inbox was read | No inbox line is checked and no state is written (AC 37, 39) |
| The window contains no meeting because a 1:1 was skipped | Not detectable and not detected; the window is time-based and simply spans two meetings' worth of material |
| Item text longer than 500 characters | Store it whole in the inbox, truncate to one line with an ellipsis in the agenda |
| Notion write fails after the local write | One line naming the failure, run still succeeds, `lastPageUrl` and `lastPageId` not written (AC 50, 51) |
| No `notionParentPageId` configured | Same as a failed write: one line saying where to set it (the plugin options or the sweep config), no page, run succeeds |
| Notion parent unreachable or the id is wrong | Same, and the message names the id it tried, so a typo is visible rather than read as a network problem |
| Fathom unauthenticated or unreachable | Named under `sources not read`; agenda built from journals, streams, git, and the inbox; continuity falls back to the previous agenda file (AC 58, 27) |
| Fathom reachable but zero meetings in the window | Say so as a fact, not as a failure. A fortnight with no recorded meeting is a real fortnight |
| The previous 1:1 not found in Fathom | `Open from last time` comes from the previous agenda's `## Outcomes`; the agenda says the recording was not found so a thin continuity section is explained |
| No calendar event matches AC 69 in the window | No 1:1 instance to join; continuity falls back to the previous agenda file, and the agenda says the series was not found so a renamed or deleted invite is visible |
| Two candidate series after the title tiebreaker | List them, ask once, persist the `recurringEventId` (AC 72) |
| A calendar instance exists but no recording falls in its interval | The meeting happened and was not recorded; the typed recap path in AC 64 takes over |
| Two or more unclaimed candidates in the forward bracket | List them with title, duration, and id, offer the lowest id as the default, ask once, persist (AC 85). Two `Impromptu Call` recordings on 2026-07-31 are why a silent pick is not acceptable |
| Zero candidates in the forward bracket | Report the meeting unrecorded and name the bracket searched, so a too-tight `L` is distinguishable from a meeting nobody recorded (AC 86) |
| A recording ingested more than 3 hours after the meeting ended | Falsifies `L` (AC 83). The empty-join report is the signal; widen `L` rather than loosening the claiming pass |
| The recording is `labeled: false` | Content used, speakers not; feedback proposed for confirmation; assigned owners marked unreliable (AC 77 to 80) |
| A calendar instance was cancelled or moved | The event list is the source, so a moved instance simply has a new interval; a cancelled one has no interval and reads as no meeting |
| A transcript comes back empty or truncated | Treat the meeting as unrecorded for that purpose rather than summarizing a fragment; say which recording was empty |
| `find_person` returns several managers | List the candidates, confirm one, then write the config once (AC 57) |
| Manager config present but the email never matches a participant | Produce the agenda, and say the manager was not found in any recorded meeting, which is the signal that the configured email is wrong |
| Calendar or Jira fails | Named under `sources not read`; the status grid falls back to `streams.md` alone and the agenda is dated for today rather than the next 1:1 |
| `--offline` with no journal entries either | The agenda is the inbox, streams, and git only, and it says so |

Limits: the inbox is read whole and is expected to stay under a few hundred lines, so no pagination.
The window is capped at 21 days. Wins cap at 5, FYI at 3, live discussion at 5, meeting summaries at
12, transcripts at 1. The question budget is 2 on assemble and 1 on recap, or 4 on recap when no
recording was found.

## Open questions

Three are resolved and kept for the record. The rest carry the default I would ship on and what a wrong
guess costs.

1. **Does the agenda get written to Notion as well as the local file?** **Resolved: yes.** It reuses
   `notionParentPageId` and the `/sweep` step 1 resolution, and it is written after the local file so a
   Notion failure cannot cost the user the agenda (AC 48 to 53). This moved the Notion write out of the
   non-goals and into `v1 does`.
2. **How does the manager actually receive this, and when?** **Resolved: as a Notion page, read a day
   ahead.** No pasted block, so no `--paste-for slack|email` rendering split in v1. The stdout copy
   stays, because it is how the user sees exactly what the page carries before anyone else reads it.
3. **Is the monthly OKR 1:1 cadence-derived or explicit?** Default: derived from `lastOkrCoveredAt`
   with `--okr` and `--no-okr` overrides (AC 16 to 18). The `ledger.md` review cadence says every 2
   months while the request says monthly, so these are two different rhythms and the agenda's monthly
   section is not the bi-monthly review doc. Confirm that reading.
4. **Should the recap append the OKR movement to `~/.claude/polaris-memory/okr/log.md`?** Default:
   no, `/sweep`'s evening block owns that write. Cost: a KR that visibly moved during the 1:1 gets
   discussed and then logged again in the evening, or not at all.
5. **Is `/oneonone add` cheap enough to actually get used?** **Resolved: yes, the slash command is the
   capture path.** R1 ships as written. The metric that tested this stays, because a confirmed intention
   and a habit that holds for eight weeks are different claims: if the median `inbox:` count per agenda
   comes in at zero, the capture surface is the first thing to revisit, and the alternatives remain a
   `stop-capture`-style hook prompt or a line in `/track`.
6. **Does the mode belong in `rules/flows.json` as a flow row?** Default: no. A flow is for work with
   phases the gates enforce, and capture-assemble-meet-recap spans days and a meeting a hook cannot
   observe. It stays a command.
7. **Should `enhance-prompt` route "prep me for my 1:1" to this command?** Default: yes, one row in
   the `routing` class of `rules/patterns.json`, since a user who says it in prose should land here.
8. **Are non-work rapport prompts wanted?** The threads say a little genuine non-work talk is what
   makes hard conversations possible. Default: out of v1. Generated small talk is worse than none.
9. **Is `.polaris/work/streams.md` the right status grid source across projects?** Default: yes, plus
   the Jira JQL and the projects named in the window's journal entries. It is per-project, so a project
   the user did not open in Claude Code this fortnight has no streams file to read and reaches the grid
   only through Jira.
10. **Should the Notion page carry the outcomes, or stay the pre-meeting snapshot?** Default: carry
    them (AC 52), and the argument runs both ways. For leaving it frozen: the page is what the manager
    read before the meeting, and editing it after means the artifact the two of them discussed no
    longer exists, which matters if anyone ever cites it. For updating it, which wins: the threads want
    the recap to be a paper trail the manager can see, and a local-only outcomes section is a private
    diary that does the user no good at review time. Two divergent records of one meeting is the worse
    failure, and appending under a dated `## Outcomes` heading leaves the pre-meeting sections
    untouched, so nothing is rewritten, only added. The drafted message in AC 31 stays regardless,
    because a page edit notifies nobody.
11. **Does Fathom expose a recording start time finer than the date?** **Resolved by measurement, and the
    answer was more useful than a yes.** `created_after` and `created_before` do filter at sub-day
    precision, so a time join is buildable and the pick-once path is a fallback rather than the mechanism.
    The finding that mattered is that `created` is ingest time, not meeting start: five bracketed
    `list_meetings` calls put the 2026-07-22 recording's `created` between 11:40Z and 12:30Z for a meeting
    that ended at 11:00Z, and the bracket around the event itself returned nothing. AC 73, 83, and 87 hold
    the consequences. What remains unknown, and is now a smaller question: whether the per-recording
    timestamp is readable in the output rather than only filterable. If it is, the claiming pass in AC 84
    becomes local arithmetic and the extra bracketed call in AC 54 disappears.
12. **Should Slack come in as a second-round source?** Default: no, and revisit only if the agenda
    visibly misses things the user raised in Slack. It is the most expensive read available and the
    journals already carry it per day.
13. **Do the calendar OKR blocks belong in the OKR section?** **Resolved: yes, for intent only.** The
    argument against is real, that a second source of OKR truth undermines the ledger, and AC 82 answers
    it by never reading a number from an event description. What the blocks add that `progress.json`
    cannot is where the time actually went: a quarter with O2 at zero and no `Delivery Excellence · O2`
    block kept in eight weeks is a different conversation from one where the time was blocked and the
    result still did not come. The calendar call already happens for AC 69, so this costs nothing.
14. **Does the grammar-based direction heuristic in AC 78 earn its place, or should an unlabeled recording
    contribute no feedback at all?** Default: keep it, marked `confirm`. The strict alternative, that an
    unlabeled recording contributes content but never a feedback candidate, is safer and loses the single
    highest-value thing in the offline 1:1. If confirmations turn out to be mostly rejections, cut the
    heuristic rather than tuning it.

## Assumptions still open

- `A1` Fathom, Calendar, and Jira are read live for the window, with journals as the fallback and the
  cross-check. Rewritten from the opposite call; the reasoning is in `Derived versus asked`.
- `A2` The state lives at `~/.claude/polaris-memory/oneonone/`, user-level, because a manager
  relationship is not per-repository. Nothing is written into a project. `config.json` sits beside
  `state.json` and holds only decisions the user made, currently just a disambiguated `recurringEventId`,
  so clearing a stuck cursor does not erase a choice. That is the split `/sweep` already keeps between its
  config and its state.
- `A3` The inbox stores raw text with no bucket, and the bucket is assigned when the agenda is built.
  The user will not type a category mid-thought, and classification is a model job under Rule 5.
- `A4` Both the bi-weekly and the monthly variant produce the same six sections; monthly adds one.
  Two document shapes would double the surface for one extra section.
- `A5` The window cap is 21 days. A gap longer than that means a 1:1 was missed and the older
  material is stale anyway.
- `A6` One agenda file per date, overwritten on a repeat run, matching `/sweep`'s same-title rule, and
  one Notion page per date updated in place.
- `A7` Three stages in this order, and the failure semantics differ per stage: derive over the network,
  where a source failure degrades the content and names itself; write the local file and stdout, where a
  failure means nothing was recorded and stops the run; write the Notion page, where a failure costs the
  page and nothing else. The alternative, writing the page first so the manager-facing artifact is never
  missing, loses the rushed-Tuesday run to a slow network and can leave a page whose local counterpart
  was never written. Local first is the reversible order.
- `A8` Three live sources in v1, five deferred, argued source by source in the table above.
- `A9` The calendar identifies the meeting and the manager, and Fathom is joined to it by ingest time
  running forward from the event. The reverse, finding the 1:1 in Fathom and inferring the manager from
  participants, fails on the observed data: the 2026-07-22 recording carries no `calendar_invitees`. A
  structural calendar test survives a renamed invite; a title match does not.
- `A11` The ingest-lag bound is 3 hours from one sample, and it is the weakest number in this spec. It is
  written as a single named constant so widening it is a one-line change, and AC 86's empty-join report is
  the instrument that tells you to. Recording ids happen to increase with time across the 13 observed
  meetings, and AC 87 keeps that fact in the display layer where a broken assumption costs an odd sort
  order rather than a wrong attribution.
- `A10` Speaker attribution on an unlabeled recording is unrecoverable and stays unrecovered. The whole
  design of R13 is to keep the uncertainty visible rather than to resolve it, because the cost of a wrong
  attribution here is paid in front of the manager.
