---
description: >
  Initialize or improve CLAUDE.md for the current project. If no CLAUDE.md exists,
  creates one with the full 12-rule behavioral baseline + project-specific context.
  If CLAUDE.md already exists, audits it and fills any gaps.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

# CLAUDE.md Initializer

Creates or improves CLAUDE.md for the current project, combining a universal behavioral
rule baseline (Karpathy 12-rule template) with project-specific context.

**Hard ceiling: keep the generated file under 200 lines.** Compliance drops past it.

---

## Step 1: Check for Existing CLAUDE.md

```bash
find . -maxdepth 1 -name "CLAUDE.md" 2>/dev/null
```

- **File found** → skip to Step 3 (audit mode).
- **No file** → proceed through Steps 2 → 3 (create mode).

---

## Step 2: Scan Project Context

Run these in parallel to gather project-specific information:

```bash
# Detect stack and commands
cat package.json 2>/dev/null | head -40
cat pyproject.toml 2>/dev/null | head -30
cat Cargo.toml 2>/dev/null | head -20
cat Makefile 2>/dev/null | head -40

# Check for existing guidance files
cat README.md 2>/dev/null | head -80
cat .cursorrules 2>/dev/null
cat .cursor/rules/*.md 2>/dev/null
cat .github/copilot-instructions.md 2>/dev/null

# High-level structure (two levels deep, no node_modules/.git)
find . -maxdepth 2 -type d \
  -not -path './.git*' \
  -not -path './node_modules*' \
  -not -path './.next*' \
  -not -path './dist*' \
  -not -path './__pycache__*' \
  2>/dev/null
```

Extract:
- Build / dev / test / lint commands
- Top-level directory purposes (where does what live?)
- Non-obvious gotchas from README or cursor rules
- Any environment variable requirements

---

## Step 3: Generate or Audit CLAUDE.md

### Create Mode (no existing file)

Write `CLAUDE.md` to the project root using the template below.
Fill in the `[PROJECT SECTIONS]` with what you found in Step 2.
Only include project sections that have real content — omit empty ones.

### Audit Mode (file exists)

Read the existing file. Check:
1. Are all 12 behavioral rules present (or equivalent coverage)?
2. Are the Commands/Architecture sections current and accurate?
3. Is total length under 200 lines?

Propose targeted additions only. Show diffs. Apply after user confirms.

---

## CLAUDE.md Template

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Behavioral Rules

These rules apply to every task unless explicitly overridden.
Bias: caution over speed on non-trivial work.

### Rule 1 — Think Before Coding
State assumptions explicitly. Ask rather than guess.
If multiple interpretations exist, present them — don't pick silently.
Push back when a simpler approach exists. Stop when confused.

### Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
No "flexibility" or "configurability" that wasn't requested.
If you write 200 lines and it could be 50, rewrite it.

### Rule 3 — Surgical Changes
Touch only what you must. Don't improve adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.
Remove imports/variables/functions that YOUR changes made unused.
Don't remove pre-existing dead code unless asked.

### Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
For multi-step tasks, state a brief plan with numbered steps before touching code.
Strong success criteria let Claude loop independently.

### Rule 5 — Use the Model Only for Judgment Calls
Use for: classification, drafting, summarization, extraction.
Do NOT use for: routing, retries, deterministic transforms.
If code can answer, code answers.

### Rule 6 — Token Budgets Are Not Advisory
If a session is spiraling or re-suggesting rejected fixes, summarize and start fresh.
Surface the breach. Do not silently overrun.

### Rule 7 — Surface Conflicts, Don't Average Them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup. Don't blend conflicting patterns.

### Rule 8 — Read Before You Write
Before adding code, read exports, immediate callers, shared utilities.
If unsure why existing code is structured a certain way, ask.

### Rule 9 — Tests Verify Intent, Not Just Behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

### Rule 10 — Checkpoint After Every Significant Step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back. If you lose track, stop and restate.

### Rule 11 — Match the Codebase's Conventions, Even if You Disagree
Conformance > taste inside the codebase.
If you think a convention is harmful, surface it. Don't fork it silently.

### Rule 12 — Fail Loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

---

[PROJECT SECTIONS — fill in from scan, omit empty ones]

## Commands

| Command | Description |
|---------|-------------|
| `<command>` | <description> |

## Architecture

<high-level directory map with one-line purpose per entry>

## Gotchas

- <non-obvious thing that causes issues>
```

---

## Output Rules

- Prefix file with the exact header shown in the template.
- Behavioral rules section is non-negotiable — always included verbatim.
- Project sections use real commands from the actual codebase, not placeholders.
- If a project section would be empty or obvious, omit it.
- Final file must be **≤ 200 lines**. If project context pushes past it, trim the
  least critical gotchas/architecture entries — never trim the behavioral rules.
