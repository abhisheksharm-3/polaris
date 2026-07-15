# Polaris Core Engineering Standard

<!-- Language-agnostic. Injected every session. Hard constraints, not suggestions. -->
<!-- Stack-specific opinions live in rules/stacks/<stack>.md. Prose rules live in rules/writing.md. -->

## Philosophy

Code must be sustainable in production: simple, performant, secure, self-explanatory, and low in
complexity. Write the minimum that solves the problem. No speculative features, no abstractions
for single-use code, no configurability nobody asked for, no error handling for impossible
states. If 200 lines could be 50, write 50.

Dead-code and backward-compatibility policy are read from `.polaris/config.json`, not hardcoded.
The greenfield default is: no external consumers, so change freely and delete dead code on sight.
A project that sets `backwardCompat: "maintain"` or `deadCode: "keep"` overrides this.

## The laziness ladder (before writing code)

Before writing any code, climb down this ladder and stop at the first rung that solves the problem.
The best code is the code you did not write. This is the ponytail minimalism discipline, and every
code-writing agent applies it.

1. **YAGNI.** Does this need to exist at all? Build only what the task asks for now.
2. **Reuse.** Does code in this repo already do it? Use or extend that; do not write a second one.
3. **Standard library.** Does the language's standard library cover it? Prefer it over a dependency.
4. **Native platform.** Does the framework or platform already provide it? Use the built-in.
5. **An installed dependency.** Is it already in the project? Use it before adding a new one.
6. **A one-liner.** Can it be a small, clear expression rather than a new abstraction?
7. **A minimal implementation.** Only now write new code, and only the minimum that solves it.

Adding a new dependency, a new abstraction, or a new file is the last resort, and it carries the
burden of proof. The ponytail companion enforces this ladder (default level `full`) and injects it
into every subagent, so the fleet applies it automatically; `rules/routing.md` says which intensity
fits which task, and `/ponytail-review` audits a diff for over-engineering.

## Root cause, not symptom

When a bug is found, fix the logic that caused the whole class of bug so it never recurs. Never
make a check pass with a hardcode, a hacky patch, or an anti-pattern. Never treat the symptom.

## No workarounds, ever

- If something cannot be implemented correctly, stop and explain why. Do not write a workaround.
- No `TODO: fix later`. Fix it now or do not write it.
- No type escape hatches (`as any`, `@ts-ignore`, and their equivalents in other languages)
  without a documented framework-bug reason.
- No bare catch blocks that swallow errors silently.

## One file, one responsibility

Every file has a single, clearly stated purpose. If you cannot describe what a file does in one
sentence without using "and", split it. A file growing large is usually a sign it does too much.

## No orphan code

Every exported symbol is imported somewhere. Every file is imported by at least one other file or
is an entry point. Delete dead code immediately when the project's policy allows it; do not
comment it out.

## No duplicate code

Before writing a new utility, search for an existing one. If it exists, reuse it (export or move
it to a shared location if needed). Never keep two functions that do the same thing.

## Comments policy

Only doc comments (JSDoc, docstrings, or the language's convention) and single-line comments that
explain a non-obvious WHY. Nothing else. If removing a comment would not confuse a reader, remove
it. Never narrate what the code does, journal what changed, or defer work in a comment.

## Naming

Names carry the meaning so the code reads without comments. Booleans read as questions
(`isLoading`, `hasError`). Handlers say what they handle (`handleSubmit`). Constants are loud.
The stack overlay defines the exact casing and suffix conventions for its language.

## Fetch fresh docs before writing (the docs protocol)

Before implementing or auditing anything in a stack, resolve current, version-correct knowledge.
Never rely on training data for version-specific APIs.

1. Detect the installed version from the manifest (`package.json`, `pyproject.toml`, `go.mod`,
   `Cargo.toml`, and so on).
2. Load the relevant host skill for the stack (see `rules/stack-map.json`).
3. Fetch fresh docs in this order: `llms.txt` or `llms-full.txt` at the framework's doc domain,
   then the version-specific official docs, then a targeted web search.
4. Combine the skill and the fresh docs to do the work.

## Karpathy mode rule: surgical versus aggressive

Two stances apply in different modes, and they never contradict because they never run at once.

| Mode | Rule |
|---|---|
| Feature implementation | **Surgical.** Touch only what the task requires. Every changed line traces to the request. Do not refactor or reformat adjacent code. Remove only the orphans your own change created. Note unrelated dead code; do not delete it. |
| Explicit cleanup, audit, or refactor | **Aggressive.** Delete dead code, remove backward-compat shims (when policy allows), split oversized files, fix anti-patterns across the touched area. This is the invoked job. |

Never scope-creep during a feature. Clean aggressively only when cleanup is the task.

## Think before coding, verify after

State assumptions before implementing. If two interpretations exist, present both. If a simpler
path exists, say so. If something is unclear, stop and ask. Turn every task into a verifiable goal
with an explicit success check, then loop until the check passes.
