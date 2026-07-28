---
date: 2026-07-28
task: pull every connector into /journal, and read Slack thread replies in journal, sweep, catchup
---

# Flow run — journal connectors and the Slack thread fix

Task: `/journal` pulls only local transcripts and git. Make it pull every source the day touched —
Jira, Slack, GitHub, Gmail, Calendar, Fathom, Claude memory, the day's sweep briefing. Root-cause the
reported Slack gap (thread replies are never read) and fix it everywhere it exists: journal, sweep,
catchup.

## Timeline

- Discovery — read journal.md, sweep.md, catchup.md, journal-facts.sh, and the Slack tool schemas.
  Root cause found: `slack_read_channel` returns channel-level messages only, so thread replies are
  invisible, and a reply under an out-of-window parent is invisible twice over. Same defect in three
  commands.
- Plan — approved by the user, who also asked for DMs since the last run and for catchup to be fixed
  in the same pass.
- Implement — new `rules/connectors.md` (one shared read protocol, six-step Slack sequence, DM
  discovery, per-source recipes, unavailable-source rule). `scripts/journal-facts.sh` gained `gh` PR
  and issue facts, cross-repo GitHub activity, Polaris artifacts, the day's sweep briefing url, and
  memory written that day; `gh` is gated off the hook path so session start stays fast. All three
  commands now cite the rule.
- QA — reproduced the bug on live data: reply in `#n2-sage` at 12:37 IST under a parent from
  2026-07-27 20:41 IST, absent from a windowed channel read, found by search plus
  `slack_read_thread`. Exposed a second trap: search reports the reply's ts, and the parent ts is
  only in the permalink `?thread_ts=`. Documented.
- Verify — full suite green (5 new checks: memory reported, memory date-scoped, `gh` skipped for the
  hook, `gh` run for `/journal`, all three commands cite the rule). Prose gate clean on all five
  changed markdown files.
