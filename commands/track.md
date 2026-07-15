---
description: Update the work tracker: reconcile this session's work into .polaris/work/streams.md
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Update the work tracker

Keep `.polaris/work/streams.md` current so no thread is lost between sessions. You maintain it; the
user should not have to.

## Steps

1. Read `.polaris/work/streams.md`. If it does not exist, create `.polaris/work/` and copy
   `${CLAUDE_PLUGIN_ROOT}/templates/work-streams.md`, then clear the example streams.
2. Review what this session actually did: the prompts, the files changed (`git status -s`,
   `git diff --stat`), and the open threads discussed.
3. Reconcile the streams:
   - Add a stream for any new thread of work that started.
   - Update the `state`, `next`, `files`, and `touched` of any thread that moved.
   - Mark finished threads `done` and move them to the `## Done` archive with a one-line record.
   - Flag any active thread untouched for a while so it does not get forgotten.
4. Keep the file lean: active and blocked streams at the top, done ones archived, and drop archived
   records once they are no longer useful. One thread per stream, the single next step named.
5. Write the file back. It passes the writing standard.

Report a one-line summary: how many streams are active, blocked, and closed.
