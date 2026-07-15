# Slice F: Prompt Enhancing — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §9. Milestone M5. Depends on Slice A.

Toggleable prompt enhancement in two steps, so it never touches a prompt that was already clear.

## Problem

A vague or underspecified prompt sends work in the wrong direction. But blindly rewriting every
prompt is worse: it churns clear ones and adds noise.

## Goal

A judge-then-enhance step, off by default, on per project via config. It judges whether
enhancement is needed and, when it is, enriches with project context. Plus an explicit `/enhance`
command for on-demand rewrites.

### Success criteria

- `promptEnhance` in `.polaris/config.json` (default false) gates the automatic step.
- `hooks/enhance-prompt` (UserPromptSubmit): when enabled, injects a judge-then-enhance directive as
  `additionalContext`; when disabled, stays silent. It never rewrites the prompt (the hook API does
  not allow it), so it directs Claude to self-assess and enrich only if the prompt is vague.
- `/enhance` rewrites a given prompt with full context, wiring the EARS `prompt-optimizer` skill.
- A test confirms the hook injects when enabled and is silent when disabled.

## Architecture

### The judge-then-enhance directive (automatic, gated)

`hooks/enhance-prompt` reads the config. When `promptEnhance` is true, it injects:

> Before acting: judge whether this request is clear and specific. If it is, proceed as written. If
> it is vague, ambiguous, or underspecified, first restate it precisely using the project config,
> the standard, and the codebase, name the assumptions you are making, and then act on the restated
> version.

This is the honest mechanism: a `UserPromptSubmit` hook cannot rewrite the prompt, so it directs
the judge-then-enhance in-model rather than silently replacing text. Off by default so it never
adds noise unasked.

### The explicit rewrite (`/enhance`)

`commands/enhance.md`: take a prompt in `$ARGUMENTS`, judge it, and if it needs work, produce an
enriched version using the project config, memory, the repo, and connector context, wiring the
`prompt-optimizer` skill (EARS). Return the enriched prompt for the user to run, or run it if asked.

### Files

```
templates/config.default.json  + "promptEnhance": false
hooks/enhance-prompt           UserPromptSubmit judge-then-enhance (gated)
hooks/hooks.json               + register UserPromptSubmit
commands/enhance.md            explicit rewrite
tests/run-tests.sh             + enable/disable assertions
```

## Testing

- Feed `enhance-prompt` a UserPromptSubmit payload with a project config where `promptEnhance` is
  true (temp dir) and assert it emits `additionalContext`; with it false, assert silence.

## Out of scope

- H (dynamic synthesis), E (memory).
