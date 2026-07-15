---
description: Write or regenerate the daily journal for a day, across all projects
argument-hint: "[date, default today]"
allowed-tools: Read, Write, Bash, Grep, Glob, Task
---

# Journal

Write the journal for the day in `$ARGUMENTS` (a `YYYY-MM-DD` date), or today when no date is
given. The journal is a dated, cross-project record kept at `~/.claude/polaris-memory/journal/`.

## Steps

1. Resolve the date: use `$ARGUMENTS` if it is a `YYYY-MM-DD` date, else today (`date +%F`).
2. Build the facts:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/journal-facts.sh" <date> /journal`
   If it prints nothing, tell the user there was no recorded activity that day and stop.
3. Write `~/.claude/polaris-memory/journal/<date>.md`: keep the per-project facts sections as the
   evidence, and add a prose narrative under the `# <date>` heading that tells what happened and
   why, grounded only in those facts. Set the frontmatter `status: narrative`. When the date is
   today, label the entry as the day in progress.
4. Summarize intent and actions. Do not copy transcript text or file contents into the journal,
   and redact any secret that appears in a prompt.
