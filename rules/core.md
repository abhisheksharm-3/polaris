# Polaris Core Engineering Standard

<!-- The only rules file injected every session, so it has a 7,000-byte budget: the hook cap is -->
<!-- 10,000 characters and the overflow is silently replaced by a file path. Comment law and -->
<!-- ladder first, because truncation keeps the start. Everything else loads on demand. -->

## Comments policy

A low comment count is the first signal of good code. The code carries its own explanation through
names, small functions, and control flow a reader can follow in one pass. A comment is what you
write when that failed, so before you write one, rename the variable, extract the function, or
delete the branch instead.

Comments are allowed in exactly two places:

1. **The top of a file**, stating that file's single purpose in a line or two.
2. **Directly above a declaration**, documenting a function, class, type, or exported constant.

Both use the language's doc convention in its multi-line form: `/** ... */` for TSDoc and JSDoc,
`"""..."""` for Python, the `// ...` block immediately above the declaration for Go, `/// ...` for
Rust. Never a bare comment block standing in for a doc comment the language already has a syntax
for.

Everything else is forbidden:

- **No inline comments.** Nothing after code on the same line, ever. A trailing comment is a rename
  waiting to happen.
- **No comments inside a function body.** A step that needs narrating is a function that needs
  extracting, and the extracted name is the comment.
- **No narration** of what the code does, no journal of what changed, no `TODO`, no commented-out
  code, no metadata (author, date, ticket number). Git holds the last four.

A doc comment states what a caller needs and cannot read off the signature: the contract, the
units, the failure mode, the non-obvious why. If it restates the signature, delete it.

**The one exception.** A constraint the code genuinely cannot express, a workaround for a verified
external bug, or a ponytail ceiling marker naming a deliberate simplification, goes on its own line
directly above the code it explains, or inside the enclosing declaration's doc comment. Never
trailing. It carries the reason, never a restatement.

`check-patterns.sh` catches a trailing comment deterministically and `guard-edit` denies the write;
the rest is the gate's judgment pass.

## The laziness ladder (before writing code)

Climb down this ladder and stop at the first rung that solves the problem. The best code is the code
you did not write. Every code-writing agent applies it.

1. **YAGNI.** Does this need to exist at all? Build only what the task asks for now.
2. **Reuse.** Does code in this repo already do it? Use or extend that; do not write a second one.
3. **Standard library.** Does the language's standard library cover it? Prefer it over a dependency.
4. **Native platform.** Does the framework or platform already provide it? Use the built-in.
5. **An installed dependency.** Is it already in the project? Use it before adding a new one.
6. **A one-liner.** Can it be a small, clear expression rather than a new abstraction?
7. **A minimal implementation.** Only now write new code, and only the minimum that solves it.

A new dependency, a new abstraction, or a new file is the last resort and carries the burden of
proof. The ponytail companion enforces this ladder and injects it into every subagent;
`/ponytail-review` audits a diff for over-engineering.

## Philosophy

Code must be sustainable in production: simple, performant, secure, self-explanatory, and low in
complexity. Write the minimum that solves the problem. No speculative features, no abstractions for
single-use code, no configurability nobody asked for, no error handling for impossible states. If
200 lines could be 50, write 50.

Dead-code and backward-compatibility policy come from `.polaris/config.json`, not from here. The
greenfield default is no external consumers, so change freely and delete dead code on sight;
`backwardCompat: "maintain"` or `deadCode: "keep"` overrides that.

## Root cause, not symptom

When a bug is found, fix the logic that caused the whole class of bug so it never recurs. Never make
a check pass with a hardcode, a hacky patch, or an anti-pattern. Never treat the symptom.

## No workarounds, ever

- If something cannot be implemented correctly, stop and explain why. Do not write a workaround.
- No `TODO: fix later`. Fix it now or do not write it.
- No type escape hatches (`as any`, `@ts-ignore`, and their equivalents) without a documented
  framework-bug reason.
- No bare catch blocks that swallow errors silently.

## One file, one responsibility

Every file has a single, clearly stated purpose. If you cannot describe what a file does in one
sentence without using "and", split it. A file growing large usually means it does too much.

## No orphan code

Every exported symbol is imported somewhere. Every file is imported by at least one other file or is
an entry point. Delete dead code immediately when the project's policy allows it; do not comment it
out.

## No duplicate code

Before writing a new utility, search for an existing one. If it exists, reuse it, exporting or
moving it to a shared location if needed. Never keep two functions that do the same thing.

## Naming

Names carry the meaning so the code reads without comments. Booleans read as questions
(`isLoading`, `hasError`). Handlers say what they handle (`handleSubmit`). Constants are loud. The
stack overlay defines the exact casing and suffix conventions for its language.

## Think before coding, verify after

State assumptions before implementing. If a simpler path exists, say so. Turn every task into a
verifiable goal with an explicit success check, then loop until the check passes.

Whether to ask or infer depends on the kind of decision, not on how sure you feel:

- **Direction, what to build.** Requirements, architecture, API shape, data model, any choice that
  sets what the software does: if two readings exist, present both and ask. A wrong guess builds the
  wrong thing and surfaces three files later. The intake and design agents ask by default.
- **Implementation, how to build it.** Local, reversible choices inside an agreed task: which helper
  to reuse, how to structure a function, a name, a file split. Infer the sensible default from the
  config and the surrounding code, state it in one line, and loop to the success check.
- **Ask mid-implementation only** when the choice materially changes the outcome and cannot be
  inferred, or when the action is hard to reverse or outward-facing (a migration, a delete, a
  deploy, an external call). Then confirm first.

## The named smells

`rules/clean-code.md` holds the catalog (N, F, G, T) so a finding can be cited rather than argued:
`F3 | src/render.ts:8 | flag argument, split the function`. Load it for code work, with the stack
overlay. It is not injected.
