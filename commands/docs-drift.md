---
description: Find docs that no longer match the code and bring them back in sync
argument-hint: "[a docs path or area, or the whole repo]"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write
---

# Docs drift

Find where the documentation in `$ARGUMENTS` has fallen behind the code and fix it. Read
`.polaris/config.json` first.

## Steps

1. **Pair docs with code.** For each doc (README, API docs, guides, ADRs), find the code it
   describes. Read both.
2. **Detect drift.** Look for docs that reference a renamed or removed function, an old command or
   flag, a changed API shape, a stale config key, or an example that no longer runs. Cross-check
   commands and code snippets against the current code; run them where cheap.
3. **Rank.** A doc that will actively mislead (a wrong command, a removed API) outranks a cosmetic
   staleness.
4. **Fix.** Dispatch `tech-writer` to update each drifted doc to match the shipped code, with real
   commands and paths, held to the writing standard and with no AI attribution. Remove docs for code
   that no longer exists.
5. **Report.** List what drifted and what was fixed. Note any doc whose code you could not locate,
   for a human to resolve.

## Rules

- Docs describe the shipped code, not the intended code.
- Do not invent behavior to match a doc; fix the doc to match the code, or flag the mismatch.
