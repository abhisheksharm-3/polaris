---
date: 2026-07-28
run: .polaris/runs/2026-07-28-flow-journal-connectors.md
commit: 9b5dc3a
---

# Journal connectors and the Slack thread fix

## What was built

`rules/connectors.md`, a shared protocol for reading a bounded window of work out of every connected
source, and three commands that now follow it: `/journal`, `/sweep`, `/catchup`.

`/journal` pulls the local record (sessions, asks, commits, changed files, PRs, Polaris artifacts,
memory written that day) plus the connected record (Jira, Slack including threads and DMs, GitHub,
Gmail, Calendar, Fathom) plus the day's sweep briefing, then writes facts, connector sections with
deep links, and a narrative.

`scripts/journal-facts.sh` grew four fact types: per-repo PRs via `gh pr list`, cross-repo authored
and reviewed PRs and involved issues via `gh search`, `.polaris/` artifacts dated that day, and memory
files written that day. `gh` runs only when the caller is not the session-start hook, so startup keeps
its sub-ten-second budget while `/journal` pays about ten seconds for the network.

## What was found and fixed

The Slack complaint had one cause, present in three commands. `slack_read_channel` returns
channel-level messages only; a thread reply is absent unless its author also sent it to the channel.
Reproduced on live data: a reply in `#n2-sage` at 12:37 IST under a parent from 2026-07-27 20:41 IST
was missing from a channel read scoped to 2026-07-28, and both the parent and the reply came back once
the run searched `from:<@USER_ID> on:2026-07-28` and expanded the thread by its parent ts.

The same defect broke `/sweep` resolution: its rule asks whether the user replied in the thread, and
without a thread read the answer was always no, so mentions carried forever. That row now names
`slack_read_thread` as the only admissible evidence.

A second trap surfaced during QA: Slack search reports the reply's own ts as `Message_ts`, and the
parent ts appears only in the permalink query string. Passing the reply's ts to `slack_read_thread`
returns nothing, so the rule states where to read the parent ts from.

## Verification

`bash tests/run-tests.sh` passes, with five new checks: memory writes are reported, memory is
date-scoped, `gh` is skipped on the hook path, `gh` is queried for `/journal`, and each of the three
commands cites the connectors rule. The prose gate passes on all five changed markdown files.

## Residual risk

- DM discovery works by searching `from:` and `to:me` with `channel_types: "im,mpim"`, so a DM whose
  only traffic in the window is a file, an emoji reaction, or a message no search term matches can be
  missed. A conversation-list tool would close this; none is exposed today.
- Slack search returns 20 results per page. The rule says to page with `cursor`, and a run that ignores
  that reports a partial day.
- The session-start lookback still writes connector-free skeletons for missed days, because pulling
  connectors at startup would cost network time and permission prompts. Running `/journal <date>` for
  such a day regenerates it in full.
- Two sweeps in one day leave only the later page url in state; the earlier one is found by title.

## Spend

Telemetry is not enabled, so no figure is recorded. One session, no subagents dispatched.
