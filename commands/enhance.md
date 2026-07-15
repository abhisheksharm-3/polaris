---
description: Judge a prompt and, if it is vague, rewrite it precisely with full project context
argument-hint: "<the prompt to enhance>"
allowed-tools: Read, Bash, Grep, Glob
---

# Enhance a prompt

Take the prompt in `$ARGUMENTS` and make it precise, only if it needs it.

## Steps

1. Judge it. If the prompt is already clear and specific, say so and return it unchanged. Do not
   churn a good prompt.
2. If it is vague, ambiguous, or underspecified, rewrite it precisely using the project context:
   `.polaris/config.json`, the Polaris standard, the relevant memory, the codebase, and connector
   context when useful. Wire the `prompt-optimizer` skill (EARS) for the rewrite.
3. Name the assumptions the rewrite makes, so the user can correct them.

Return the enriched prompt for the user to run, or run it directly if the user asked you to. The
output passes the writing standard.
