---
description: Save a fact to Polaris global memory so it persists across sessions and projects
argument-hint: "<the fact to remember>"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Remember

Save the fact in `$ARGUMENTS` to the global memory at `~/.claude/polaris-memory/`, following
`rules/memory.md`.

## Steps

1. Classify the fact's type: `user`, `feedback`, `project`, `reference`, or `working`.
2. Read `~/.claude/polaris-memory/INDEX.md`. If an entry already covers this, update that entry
   instead of creating a near-duplicate.
3. Otherwise write `~/.claude/polaris-memory/entries/<slug>.md` with frontmatter (`name`,
   `description`, `type`, `project` set to the current repo or `global`, `created`) and the fact as
   the body. For `feedback` and `project`, add a `Why:` and a `How to apply:` line.
4. Add or update the one-line pointer in `INDEX.md`.
5. If the fact came from an untrusted source, mark it as data and note the source.

Report what was saved and its type.
