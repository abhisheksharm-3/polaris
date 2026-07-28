# Polaris Clean Code Catalog

<!-- Language-agnostic. Loaded for code work, not injected every session (see core.md skill resolution). -->
<!-- Adapted from Clean Code (Robert C. Martin), chapter 17, and the clean-dry-code-skills rule set -->
<!-- (github.com/aakashH242/clean-dry-code-skills, MIT). Rewritten and compressed for Polaris. -->
<!-- core.md owns simplicity, DRY, dead code, the comments policy, and naming basics. Where the two -->
<!-- meet, core.md wins and this file stays silent. -->

The named smells, so a finding can be cited rather than argued. Report violations by ID and the
line: `N7 | src/config.ts:12 | getConfig also writes the file`. Every code-writing agent applies
this before it reports done; the reviewer's maintainability and simplicity lenses cite from it; the
quality gate's judgment pass uses it as the checklist a regex cannot encode.

Read the stack overlay too (`rules/stacks/<stack>.md`). It owns the casing, the type rules, and the
framework specifics. This file owns the judgment that holds in any language.

## Names (N)

| ID | Rule | The tell |
|---|---|---|
| N1 | Descriptive. A name that needs a comment does not reveal intent. | `d`, `x`, `tmp`, `proc`, `data2` survive past the line that made them obvious. |
| N2 | Named at the right abstraction level. | `getMapOfUserIdsToNames` leaks the data structure; `getUserDirectory` does not. |
| N3 | Standard nomenclature. Use the domain's word and the pattern's name. | The code invents a synonym for a term the domain already has. |
| N4 | Unambiguous. | `rename(source, target)` renames what? `renameFile(oldPath, newPath)` says. |
| N5 | Length matches scope. | A one-letter index inside a three-line loop is fine; `MAX` at module level is not. |
| N6 | No encodings. No Hungarian notation, no type prefixes, no `I` on interfaces. | `arrUsers`, `strName`, `nCount`, `IUserRepository`. |
| N7 | The name states every side effect. | `getConfig` that creates the file on a miss. Rename it `getOrCreateConfig` or move the write out. |

A name that made you write a comment is the comment. Fix the name and delete the comment.

## Functions (F)

| ID | Rule | The tell |
|---|---|---|
| F1 | Three arguments maximum. | The fourth parameter means the function does too much or the arguments are one unnamed type. Pass a named object. |
| F2 | No output arguments. Return the new value. | The function mutates a parameter and returns void, so the caller cannot see what changed from the signature. |
| F3 | No flag arguments. | `render(isTest)` is two functions sharing a body. Split them; the branch was the name. |
| F4 | Delete a function nothing calls. | "Just in case" and "we might need it" both mean git holds it. |

## General (G)

The six that catch the most real damage:

- **G16 No obscured intent.** Clever is what someone decodes at 3am. `((x & 0x0f) << 4) | (y & 0x0f)`
  becomes `packCoordinates(x, y)`. If a reader has to simulate the expression to name it, name it.
- **G23 Polymorphism over a growing conditional.** A branch on a type tag that has gained a case
  twice will gain a third. Dispatch on the type instead, so adding a case adds a file rather than
  editing every switch that knows the tag.
- **G25 Named constants, never magic numbers.** `86400` says nothing; `SECONDS_PER_DAY` says it
  once, in one place, for every caller.
- **G28 and G29 Encapsulate the conditional, prefer the positive.** `if (shouldPause(timer))` beats
  an inline boolean expression, and `if (isReady)` beats `if (!isNotReady)`.
- **G30 and G34 One thing, one abstraction level per function.** If you can extract another
  function from it, it did more than one thing. A function that mixes a business rule with byte
  formatting mixes levels.
- **G36 Law of Demeter.** `context.options.scratchDir.absolutePath` couples the caller to three
  objects it does not own. Ask the one object you hold: `context.getScratchDir()`.

The rest of the catalog, each a one-line check:

G1 one language per file. G2 implement the behavior that is expected, not the one that is easy.
G3 handle every boundary condition. G4 never override a safety to make something pass. G5 DRY, in
core.md. G6 keep abstraction levels consistent. G7 a base class knows nothing of its children.
G8 keep the public surface minimal. G9 delete dead code, per the config's policy. G10 declare a
variable next to its use. G11 do the same thing the same way every time. G12 remove clutter.
G13 no artificial coupling. G14 no feature envy, logic belongs with the data it uses. G15 no
selector arguments, see F3. G17 put code where a reader would look for it. G18 prefer an instance
method to a static that takes the instance. G19 name an intermediate result rather than nesting the
expression. G20 the function name says what it does, all of it. G21 understand the algorithm before
you commit it; passing tests are not comprehension. G22 make a dependency physical, not implied by
a comment or a naming convention. G24 follow the stack's conventions and its formatter. G26 be
precise: the right type, the right rounding, the right lock. G27 structure over convention, where
the compiler can enforce it. G31 make temporal coupling explicit, so a caller cannot invert two
calls that must be ordered. G32 be deliberate; a structure with no reason is a wrong reason.
G33 encapsulate boundary conditions in one place, not `+1` scattered across callers. G35 configure
at the high level and pass it down. Never read config in a leaf.

## Tests (T)

| ID | Rule | The tell |
|---|---|---|
| T1 | Test what could break, not the happy path. | The suite is green and the divide-by-zero path has never run. |
| T2 | Read coverage as a report on gaps. | Coverage as a target produces tests that assert nothing. |
| T3 | Keep the trivial test. | It documents intent and catches the regression that the clever test misses. |
| T4 | A skipped test is an open question. | `skip` or `todo` with no reason hides an ambiguity. Answer it, or delete the test. |
| T5 | Test the boundaries. | Empty, zero, one, off-by-one, the last page, the duplicate. |
| T6 | Test exhaustively around a fixed bug. | Bugs cluster. The neighbor you did not type is the next ticket. |
| T7 | Failure patterns carry the diagnosis. | Which cases fail together names the cause faster than a debugger. |
| T8 | A coverage gap over the failing path is the suspect. | Debug by asking what was never executed. |
| T9 | Tests are fast or they get skipped. | A slow suite is a suite that stops running, which is a suite that stops working. |

Every test states why the behavior matters, so a test that cannot fail when the business rule
changes is wrong even when it passes.

## Environment (E)

E1: one command builds. E2: one command tests. A project where either takes a README paragraph and
three exported variables has a setup bug, not a documentation gap.

## Comments (C)

The Polaris comments policy in `core.md` is stricter than Martin's C1 to C5 and replaces them: doc
comments only, at the top of a file and above a declaration, in the language's multi-line doc
syntax, and no inline comments at all. `check-patterns.sh` blocks a trailing comment before the
turn continues.
