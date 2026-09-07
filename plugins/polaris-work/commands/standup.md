---
description: The two-minute standup: what you did yesterday, what you are doing today, what is blocking you
argument-hint: "[nothing, or a date to stand up for]"
allowed-tools: Read, Bash, Grep, Glob
model: sonnet
---

# Standup

Three sentences, out loud, in under two minutes. `/sweep` is the exhaustive daily pass that writes a
Notion page; `/oneonone` is the fortnight. This is the thing you say in a meeting, and every fact it
needs is already on disk.

Read `${CLAUDE_PLUGIN_ROOT}/rules/connectors.md` only if a connector read is needed for the blocked
section. The rest is local and costs nothing.

## Gather

Yesterday is the previous working day, not literally yesterday: if today is Monday, yesterday is
Friday. `$ARGUMENTS` overrides the day to stand up for.

1. **What you did.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/journal-facts.sh" <yesterday> standup`.
   That returns the projects touched, the prompts typed, the commits, and the files, for any day the
   history reaches, which is further back than the transcripts go. If a narrative journal already
   exists at `~/.claude/polaris-memory/journal/<yesterday>.md` with `status: narrative`, prefer it:
   somebody already did this work.

2. **What is open.** Every project's Polaris tracker, and any unmerged notes:
   - `.polaris/work/streams.md` in the current project, active and blocked streams only.
   - `ls .polaris/work/pending/*.md` for notes no `/polaris:track` has merged yet.
   - `bash "${CLAUDE_PLUGIN_ROOT}/../../scripts/run-state.sh" get` if a run is open here, which
     names the phase the work is actually stopped on. Skip it if the root plugin is not installed.

3. **What is blocking.** In this order, stopping as soon as you have one real answer:
   - A stream whose `status` says blocked, and what it is blocked on.
   - A run sitting on a phase marked for approval, which is blocked on a human.
   - An open PR of yours awaiting review: `gh pr list --author @me --json number,title,url,reviewDecision`.
   - A failing CI run on a branch you own: `gh run list --limit 5 --json status,conclusion,headBranch`.
   - Assigned issues or mentions from the connectors, if one is available.

## Say it

Three headings, nothing else. Every line is a thing you could say to a person.

```
Yesterday
- <what actually moved, named by its outcome and not by its commits>

Today
- <the single next step, taken from the tracker's `next` or the open run's phase>

Blocked
- <what is waiting, on whom, and since when. "Nothing" is a complete answer.>
```

## Rules

- Outcomes, not activity. "Shipped the per-session tracker key" beats "edited four files".
- One line per heading unless there are genuinely two threads. A standup that lists nine items is a
  status report nobody listens to.
- Name the person or the thing a blocker waits on. "Blocked on review" is not actionable; "waiting
  on review of PR 1054, open since Thursday" is.
- "Nothing blocked" is the right answer most days. Do not manufacture one.
- Never invent. Every line traces to a commit, a prompt, a tracker entry, or a connector read. If
  yesterday has no record, say the day has no record rather than guessing what you probably did.
- Do not write any file. This is spoken, not stored. `/journal` is where a day gets written down.
