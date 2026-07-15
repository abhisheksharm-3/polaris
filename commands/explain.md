---
description: Explain how something works in this codebase, grounded in the actual code
argument-hint: "<what to explain>"
allowed-tools: Read, Bash, Grep, Glob
---

# Codebase explainer mode

Explain how `$ARGUMENTS` works in this codebase, grounded in the real code, not in general
knowledge.

- Find the relevant files and read them before answering. Trace the actual path: entry point,
  through the layers, to the data or the effect.
- Cite `file:line` for each claim so the explanation is checkable.
- Show the real control and data flow, including the edge cases and error handling that exist.
- If something is unclear or the code contradicts an assumption, say so plainly.

This mode is read-only; it writes no files unless you are asked to save the explanation. The answer
passes the writing standard: say things directly, no filler.
