# Polaris testing standard

<!-- The one testing rule every agent that writes, judges, or runs tests reads. Each rule is tagged -->
<!-- with its source in .polaris/reports/2026-10-07-testing-research.md ([S#]). Injected in short -->
<!-- form as rules/testing-core.md. It overrides any companion skill that says otherwise. -->

A test is a cost paid on every run, by every engineer, for the life of the code. It earns its place
by catching a break that someone would actually make. The goal is the smallest suite that gives
confidence to change the code, not the largest one that can be written.

## Authority

This file overrides companion skills on what to test. superpowers `test-driven-development` says
"Never fix bugs without a test"; here a bug earns a test only under the bug rule below. The
mindrally, keel, and `clean-tests` testing skills push coverage for its own sake and are not loaded.
TDD as a way to work, red then green then refactor, still stands.

## 1. Decide before writing

1. **Name the break.** Before writing the body, write the production change that should turn this
   test red, and whether that change is a bug or a deliberate decision. No nameable bug-shaped break,
   no test. A test that fails on a deliberate decision is a change detector. [S20][S13]
2. **Test what gets broken.** Complicated conditionals, money, permissions, data that persists, code
   that changes often, and mistakes this team has made before. Not getters, setters, constructors,
   constants, forwarding, or framework mechanics, unless they validate, normalize, default, derive,
   or cause a side effect. [S1][S5][S7]
3. **A type before a test.** If a parser, a branded or narrowed type, a database constraint, or a
   lint rule can make the bad state unrepresentable, do that and write no test for the instance.
   Prevention removes the whole class; a test pins one example of it. [S11][S9]
4. **Pick the level by confidence per cost.** Mostly integration: the behavior through a real seam,
   with real collaborators where they are fast and deterministic. Unit tests for dense pure logic.
   End-to-end tests for the few journeys whose failure costs the business, never for every
   permutation. A higher-level test that finds a bug no lower test sees means a lower test is
   missing; a high-level test already covered lower down gets deleted. [S8][S9][S5][S10]
5. **The four pillars.** Protection against regressions, resistance to refactoring, fast feedback,
   maintainability. Trade the first three against each other; never trade away resistance to
   refactoring, because a test that breaks on a safe refactor is a tax with no return. [S6]

## 2. The bug rule

A fixed bug earns a test only when one of these holds, and no type, constraint, or lint can rule
the class out instead:

- The class can plausibly recur: complicated logic, frequently changed code, or a mistake made
  before.
- A recurrence is expensive: money, data loss, security, or a failure customers see.

When it earns one, test the class, not the instance: a table or a property over the input domain,
with the original reproduction as one example row inside it, at the lowest level that can see the
bug. When it does not (a typo, a wrong config value, a dependency fixed upstream, a one-off
environment cause), prove the fix by running it, say so in the RCA, and add no permanent test.
[S1][S5][S11][S14][S16] (Confidence medium: inferred from these sources; no primary source states
the rule outright, and Google's "if you liked it, put a test on it" leans the other way. [S3])

## 3. How to write one

1. **Through the public seam, the way a caller uses it.** One test per behavior, not per method,
   in arrange, act, assert form. It should survive a rewrite of the internals. [S4][S12]
2. **Assert state and output, not interactions.** "Was called with" as the only assertion is a
   change detector. [S4][S13]
3. **Real, then fake, then stub, then mock.** Use the real collaborator when it is fast,
   deterministic, and simple to build. Mock only at the process boundary: the network, the clock,
   randomness, a paid third party. Never mock the thing under test, and never assert on a mock's
   own behavior. [S13][S20]
4. **An oracle derived without the code.** The expected value is a literal or a hand-checked
   fixture. An expectation computed by the code under test, or by the same helper, passes whatever
   the code does. LLM-written tests fail here most: they copy current behavior, bugs included.
   [S20][S22][S35]
5. **No logic in a test.** No loops, branches, or computed expectations. Descriptive and repetitive
   beats clever and shared. A failure message names the input, the expected, and the actual. [S4]
6. **A property for a class of inputs.** Roundtrip, inverse, invariant, idempotence, or an oracle
   implementation, the strongest the code supports. Guard against tautology
   (`add(a, b) == a + b`) and vacuity (a filter that discards nearly every input). Code with no
   algebraic shape gets example tests, honestly. [S23][S14]
7. **Snapshots small and reviewed.** A snapshot is code: short, readable, reviewed on change, and
   never regenerated to make a red run green without reading the diff. [S15]
8. **Deterministic or deleted.** Freeze the clock, seed randomness, wait on a state and never on a
   fixed sleep, own your data so order and parallelism do not matter. [S3][S16]

## 4. Prove it can fail

Before a test counts, introduce its named break (flip the branch, change the constant, drop the
validation, return the default) and watch it go red, then restore. A test that stays green is
deleted or rewritten. When Stryker (JS/TS), PIT (JVM), or mutmut (Python) is installed, run it on
the changed lines only; a surviving mutant is a missing assertion, not a score to chase. [S20][S24][S25]

## 5. What to delete

- Change detectors: tests that fail on a deliberate change and never on a bug. [S13]
- High-level tests whose behavior a lower-level test already covers. [S5]
- Brittle tests that fail on unrelated changes. [S4]
- Tests written for a coverage number, including assertion-free ones. [S17][S29]
- Permanent tests for one-off bugs, per the bug rule.
- A flaky test nobody fixed by its quarantine expiry.

Coverage is a report on gaps, never a target. It correlates weakly with whether tests catch faults
once suite size is controlled, and a coverage gate rewards agents for tests that assert nothing.
[S19][S29]

## 6. Size budgets

| Size | Allowed | Budget |
|---|---|---|
| Small | one process, no network, disk, or sleep | under 100 ms each, 60 s per target |
| Medium | localhost only: a real database, a local server | 300 s per target |
| Large | real dependencies, a browser, multiple machines | 900 s per target, post-merge or nightly |

Report the slowest tests on every full run so outliers are visible. [S3][S33][S12]

## 7. CI by rule, never by list

- **Select from the dependency graph,** never a hand-kept list of files or suites: `vitest --changed
  origin/main` or `vitest related`, `jest --changedSince` or `--findRelatedTests`, `nx affected -t
  test`, `pytest --testmon`. [S26][S27][S28][S30]
- **Small and medium before merge, large after.** The fast set catches the large majority of what
  the full run would. [S31][S32]
- **Shard what remains,** and size workers to the runner's real cores and memory.
- **Quarantine flakes automatically** with an owner and an expiry date; on expiry the test is fixed
  or deleted, never silently skipped forever. [S16][S34]

## 8. AI failure modes to reject on sight

- A test with no assertion on an output or a side effect. [S29]
- An expectation computed by the code under test. [S35][S22]
- Mocking the subject, or asserting what a mock returns. [S20]
- A test per method instead of per behavior; a test per bug instance instead of per class.
- Assertion roulette, magic numbers, conditional logic in tests. [S36]
- `.only` committed, `.skip` with no reason and no expiry, a fixed sleep, a regenerated snapshot.
- A generated test kept because it passed once. It is kept only when it passes repeatedly and fails
  on its named break. [S37]

## 9. Who does what

- **test-engineer** owns the suite: the test plan for a change, durable tests, pruning, and CI
  selection. Every new test it keeps names its break and has been seen to fail.
- **tester** breaks the feature adversarially and hands breaks to `pin`, where test-engineer decides
  which earn a durable test.
- **e2e** writes the few browser journeys the plan calls for.
- **bug-fixer** reproduces with a test, and keeps it only under the bug rule.
- Implementers (backend, ui, frontend-logic, mobile, integrations) write the tests their slice's
  plan names, and no others.
