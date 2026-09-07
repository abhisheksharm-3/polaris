# Polaris Work

The working-life half of Polaris. It prepares the things you would otherwise assemble by hand every
morning, from state you already have.

Install it on its own. It does not need the `polaris` plugin, and `polaris` does not need it.

    /plugin install polaris-work@polaris-marketplace

## What it does

| Command | What it gives you |
|---|---|
| `/sweep` | A dated briefing in Notion, pulled from every work source, ranked so it reads from the top. Run it at the start and end of a day; the window is the time since the last run, capped |
| `/oneonone` | The bi-weekly 1:1 with your manager: capture an item any time, assemble the agenda from the fortnight, record what was agreed |
| `/journal` | A day written up across every project you touched, from your own session transcripts |

Plus the OKR lens `/sweep` reads: per-key-result pace, behind or on track or ahead, from a ledger
you keep in `~/.claude/polaris-memory/okr/`.

## Where the state lives

Everything is under `~/.claude/polaris-memory/`, which is user-level and shared across projects:

    journal/            one dated file per day, plus .last-journaled
    sweep/              config and the last-run timestamp
    okr/                the ledger, progress, log, and reviews
    oneonone/           the inbox, and what each agenda settled

## What it needs

The connectors it reads, through your claude.ai login: Notion for the briefing, plus whichever of
Slack, Jira or Atlassian, Gmail, Google Calendar and Fathom you use. `rules/connectors.md` is the
protocol for reading a bounded window out of each without losing items, including the Slack step
that expands a thread, since a channel read shows none of the replies.

Three settings are prompted at install: the Notion parent page each briefing is written under, your
IANA timezone, and the ceiling on how far back a sweep reaches when it has not run in a while.

## Why it is a separate plugin

It was part of `polaris` until 2026-09-07. By then it was 46% of that plugin's command prose and all
three of its install-time questions, while being about your job rather than about code. A developer
installing an SDLC plugin should not be asked for a Notion page id, and someone who wants a morning
briefing should not have to take a 27-agent code-review fleet with it.

The two halves share a repo, a test suite and a release, and ship as two entries in one marketplace.
