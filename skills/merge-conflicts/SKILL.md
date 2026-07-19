---
name: merge-conflicts
description: >
  Use when resolving an in-progress git merge or rebase conflict: markers left in
  the working tree, a merge or rebase that stopped and needs finishing, or files
  git reports as both-modified. Trigger phrases include "resolve merge conflicts",
  "fix the merge", "the rebase is stuck", "conflicts in these files", "finish the
  merge".
---

<!-- Adapted from mattpocock/skills (MIT): resolving-merge-conflicts -->

# Resolving merge conflicts

Resolve conflicts by intent, not by marker. The order of these steps is the mechanism:
you recover WHY each side changed before you touch a single `<<<<<<<`. Resolving markers
mechanically, picking a side because it is on top or looks newer, is how a merge silently
drops a fix.

Work top to bottom. Do not jump to step 3.

## Steps

1. **See the current state.** Run `git status` and `git log`, list the conflicted files, and
   read the conflict markers within each. Know what merge or rebase you are in and where it
   stopped before you change anything.

2. **Find the primary sources for each conflict.** For every conflicted hunk, recover why each
   side was changed and its original intent: read the commit messages, the PRs, and the issues
   behind both sides. This is the resolve-by-intent foundation. Do not resolve markers
   mechanically; a hunk you cannot explain the intent of is a hunk you cannot resolve yet.

3. **Resolve each hunk.** Go hunk by hunk, not file by file. Preserve both intents where they
   coexist. Where they are incompatible, pick the side that matches the merge's stated goal and
   record the trade-off. Do not invent new behavior to bridge the two sides. Always resolve;
   never `git merge --abort` to escape a hard conflict.

4. **Run the project's checks.** Discover the automated checks and run them. Call the Polaris
   `quality-gate` skill here rather than re-deriving the commands; the usual order is
   typecheck, then tests, then format. Fix anything the merge broke, at the root cause.

5. **Finish.** Stage everything and commit. If you are rebasing, continue with
   `git rebase --continue` and repeat from step 1 for the next conflict until every commit is
   replayed.

## Why this order

Steps 1 and 2 exist so step 3 resolves intent, not text. Skip them and you are guessing.

This aligns with the Polaris CLAUDE.md rules. Rule 7: surface conflicts, do not average them,
which is why step 3 picks a side and names the trade-off instead of blending both. Rule 12:
fail loud, which is why the trade-off is recorded in the commit or the report, not swallowed.
