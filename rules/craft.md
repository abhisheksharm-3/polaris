# Polaris Craft Principles

<!-- Language-agnostic engineering judgment. Injected every session. Complements core.md. -->
<!-- core.md owns simplicity, code-level DRY, root-cause, one-file-one-responsibility, no workarounds. -->
<!-- This file owns design judgment, adapted from The Pragmatic Programmer. No principle is restated from core.md. -->

These are the cross-cutting habits every agent applies. core.md states the hard constraints; this
states the judgment. Where the two meet, core.md wins and this file stays silent.

## Orthogonality
Keep components independent. A change in one should not force edits in unrelated ones. Tell: if
touching the payment code makes you edit the email code, they are coupled through something that
should be a boundary. Decouple through a clear interface, not a shared mutable global.

## Tracer bullets, not big-bang
For anything non-trivial, build one thin slice that runs end to end first, real input to real
output with no stubs on the critical path, then widen it. It proves the design and surfaces hard
integration early. Tell: if nothing runs until the last task, the plan is big-bang; reorder it.

## Prototype to learn, then throw it away
When the question is feasibility or shape, not delivery, build a throwaway to answer it and discard
the code (`/spike`). Never let a prototype graduate into production by inertia. Tell: if you are
polishing a prototype's error handling, you are building the real thing under a prototype's name.

## Don't live with broken windows
Fix small rot the moment you see it in code you already touch: a misleading name, a dead branch, a
test that no longer asserts anything. Rot signals that decay is tolerated, and it compounds. Tell:
"I'll clean it later" on a two-line fix is a broken window. (Cleanup beyond what you touched is
still gated by core.md's surgical rule.)

## Design by contract
State what a function requires and guarantees, and enforce it. Validate inputs at the boundary,
assert invariants, fail fast on a violated precondition rather than limping on with bad state.
Tell: a function that returns a plausible-looking wrong answer on bad input has no contract.

## Don't program by coincidence
Rely on what you know is true, not on what happens to work. If a change fixes a bug and you cannot
say why, you have not fixed it. Tell: "it works now, not sure why" means stop and find the reason
before moving on.

## Keep decisions reversible
Prefer choices you can undo. Isolate third-party services, frameworks, and other one-way doors
behind a boundary you own, so swapping them later is a local change. Tell: if replacing a vendor
means editing forty files, the decision was welded in, not made.

## Good-enough software
Engineer to the requirement and the config's policy, then stop. Know when more polish serves no
one, and when a corner is too sharp to cut. Make the quality-versus-scope tradeoff explicit to the
user rather than deciding it silently. Tell: gold-plating what nobody asked to be perfect wastes as
much as shipping what loses data.

## One source of truth (knowledge DRY)
core.md forbids duplicate code; extend the same to knowledge. A schema, a config value, or a
business rule lives in exactly one authoritative place, and everything else derives from it. Tell:
if the tax rate is written in three files, two of them are already wrong.

## Estimate honestly
Give ranges, not false precision, and say what would change the estimate. Tell: a single-number
estimate with no stated assumptions is a guess wearing a suit.
