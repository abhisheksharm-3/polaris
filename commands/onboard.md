---
description: Onboard a developer onto this project: read the repo and history, write an onboarding doc
argument-hint: "[area to focus the onboarding on]"
allowed-tools: Read, Bash, Grep, Glob, Write
---

# Dev onboarding mode

Produce an onboarding doc that gets a new developer productive on this project, focused on
`$ARGUMENTS` when given.

Read to understand the project, do not guess:

- The structure: the directory tree and what each top-level area is for.
- How to run it: build, dev, test, and lint commands from the manifests and scripts.
- The architecture and the key decisions: `CLAUDE.md`, any ADRs, the main modules and how they fit.
- Recent history: `git log` for what is active and what changed lately.
- The gotchas: env needs, non-obvious setup, things that look wrong but are intentional.

Write `.polaris/reports/<date>-onboarding-report.md`: what the project is, how it is structured,
how to run it, the architecture in brief, and a clear "start here" for the first day. It passes the
writing standard.

## Resume across sessions

<!-- progress-ledger idea from mattpocock/skills (MIT): teach -->
Onboarding runs over more than one sitting. Keep a progress ledger so a later session continues
instead of restarting. Use `.polaris/onboarding/<dev-or-topic>-progress.md`, where the slug comes
from `$ARGUMENTS` (the focus area) or the developer's name. Create the directory on demand.

At the start of a run, read this file if it exists and skip what is already covered. At the end of
every run, append a dated entry with three parts: what this session covered, open questions still
unanswered, and the next area to cover. This ledger is additive and grows over sessions; the
one-shot report above is still produced each run. Both pass the writing standard.
