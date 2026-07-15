---
description: Whole-codebase four-category audit (security, performance, architecture, structure), read-first
argument-hint: "[area or path to scope the audit, or the whole project]"
allowed-tools: Task, Read, Bash, Grep, Glob, WebFetch, WebSearch
---

# Audit

Run a whole-codebase audit over `$ARGUMENTS` (default: the whole project). Read `.polaris/config.json`
first. This is read-first: report and plan before changing anything.

## Steps

1. **Analyze.** Dispatch `audit-refactor` for the full four-category pass, no edits yet:
   security, performance, architecture, and directory structure. Collect findings with `file:line`
   and a severity rating each.
2. **Verify.** Dispatch `verifier` to confirm each high and critical finding is real and reachable,
   and drop the false positives with a note. Keep only what survives.
3. **Report.** Present the surviving findings by severity with a fix plan. Do not start fixing.

## Rules

- Read before you touch. No edits until the report is reviewed.
- Rank by real impact, not by how easy the fix is.
- After the report, chain the fixers: `/harden` for security findings, `/modernize` for dependency
  and framework work, and hand the rest to `code-cleanup` or `audit-refactor` in fix mode.
