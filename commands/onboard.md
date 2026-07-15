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
