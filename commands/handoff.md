---
description: Generate a handoff doc (feature or audit) from real repo state, into .polaris/
argument-hint: "[feature|audit] [topic]"
allowed-tools: Read, Write, Bash, Grep, Glob
---

# Handoff generator

Produce a handoff doc that lets a fresh thread continue this work without re-explanation. Fill a
template from real repository state. Never write a blank skeleton; every section is filled from
what you gather, or marked "none" when that is the truth.

## Parse arguments

From `$ARGUMENTS`: the first token is the variant (`feature` by default, or `audit`); the rest is
the topic. If no topic is given, derive a short kebab-case topic from the branch name or the main
thing changed.

## Gather real state

```bash
git branch --show-current
git status -s
git diff --stat
git log --oneline -15
git diff --name-only
```

Also read: `.polaris/config.json` (if present), the project's `CLAUDE.md`, and the relevant
Polaris memory entries. For the audit variant, resolve the audit surface: the diff against the base
branch (`git diff <base>...<branch> --stat`), with the exact file and line counts.

## Fill the template

- **feature** (default): use `${CLAUDE_PLUGIN_ROOT}/templates/handoff-feature.md`. Fill every
  section from the gathered state: what this is, current status (blunt), what is done (with commit
  hashes and passing checks as evidence), what remains (ordered, each with the next concrete step),
  how to continue (read-first order), decisions locked, gotchas, definition of done.
- **audit**: use `${CLAUDE_PLUGIN_ROOT}/templates/handoff-audit.md`. Fill the surface, the
  subsystems present in the diff, the high-risk items, the skills to load for this stack, and the
  definition of done. Keep the non-negotiable standard verbatim.

## Redact before writing

<!-- redaction-pass idea from mattpocock/skills (MIT): handoff -->
Before the content touches disk, scan it and strip anything that must not live in a repo doc:
access tokens, API keys, passwords, connection strings, private keys, and personal data (emails,
names, phone numbers) that the work does not need. A diff or a log line pasted into the gathered
state is the usual leak. Replace each with a placeholder like `<redacted:token>` and keep enough
shape that the next reader knows what was there. If a secret is load-bearing for the next session,
name where it lives (the env var, the secret manager) instead of the value.

## Write the doc

Create the directory if needed and write:

- feature: `.polaris/handoffs/$(date +%F)-<topic>-handoff.md`
- audit: `.polaris/audits/$(date +%F)-<topic>-audit-handoff.md`

Then run the doc through the writing standard and fix any hit:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check-patterns.sh" prose <the-written-file>
```

Report the path you wrote and a one-line summary of what it captures. End with a
`Suggested skills / commands for next session:` line naming the Polaris commands the next agent
should reach for, chosen from the work that remains (for example `/flow` to build, `/debug` to
chase a failing test, `/gate` before a push, `/review-pr` to review).
