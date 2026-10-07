# Testing judgment for Polaris agents: what to test, how, and when not to

Date: 2026-10-07. Question: which concrete rules should a Polaris agent apply so it writes the few tests that catch real breaks, skips or deletes the rest, and keeps CI fast by rule rather than by hand-kept lists? Decision it feeds: the testing rules in `rules/clean-code.md`, the `tester` agent, `/polaris:debug` Phase 6, and the companion list.

Sources are tagged `[S#]` and listed at the end. Confidence is high unless marked.

## The headline

The evidence supports a small rule set. Every test names the production change that would make it fail. It asserts on observable behavior through a public seam, with an expected value derived without the code under test. A bug earns a test for its class, at the lowest level that can see it, and only when the class can recur and no type or constraint can rule it out. Coverage reports gaps; mutation testing measures whether tests catch anything. CI runs what a dependency graph says is affected.

Three things in Polaris today push the other way. They are listed under (f).

## (a) Decide before writing a test

1. **Name the break first.** Before writing the body, name the production change that should fail this test, and whether that change is a bug or a deliberate decision. No nameable break, no test. [S20]
2. **Test what the team gets wrong, not everything.** Beck: "test as little as possible to reach a given level of confidence". He skips mistakes he does not make, is "extra careful" with complicated conditionals, and on a team tests "code that we, collectively, tend to get wrong". [S1]
3. **Skip code with no logic.** Getters, setters, constructors, constants, trivial forwarding, and framework mechanics earn no test unless they validate, normalize, default, derive, or cause a side effect. [S5][S20][S7]
4. **Score each test on Khorikov's four pillars:** protection against regressions, resistance to refactoring, fast feedback, maintainability. The first three trade off. Resistance to refactoring is close to binary, so it is never the one given up. [S6] (Medium: the chapter is paywalled; pillar names come from the chapter title, the trade-off from a secondary summary.)
5. **Check Beck's 12 desiderata when a test is in doubt:** isolated, composable, deterministic, fast, writable, readable, behavioral, structure-insensitive, automated, specific, predictive, inspiring. Some conflict ("predictive tests tend to be slower"), and composability resolves some of the conflicts. [S2]
6. **Pick the level by confidence per cost.** "Write tests. Not too many. Mostly integration." (Rauch, via Dodds). Integration tests give the best confidence for their cost, and static types and lint sit under the trophy to remove whole bug classes. [S8][S9] Google's count target is 80% small, 15% medium, 5% large, per team. [S3] Fowler says the shape argument is mostly about whether "unit" means solitary or sociable, and says to focus on tests that "only fail for useful reasons". [S10]
7. **Prefer a type over a test.** If a parser, a branded type, a DB constraint, or a lint rule can make the bad state unrepresentable, do that and write no test for the instance. "Use a data structure that makes illegal states unrepresentable." [S11][S9]

## (b) How to write one

1. **Call the public API the way users do.** Write one test per behavior, not one per method, in given/when/then form. [S4] Matklad's check: could the suite survive the system being replaced by "an opaque neural network"? [S12]
2. **Assert on state, not interactions.** Interaction-heavy tests become change detectors. [S4][S13]
3. **Use the real thing first.** Order of preference: real implementation, then a fake, then a stub, then a mock. A real one is right when it is "fast, deterministic, and has simple dependencies". [S13] Mock the network at the boundary, never the module under test. [S21]
4. **Derive expectations independently.** Use a literal or a hand-checked fixture. An expected value built by the code under test or its helpers passes no matter what the code does. [S20][S22]
5. **No logic in tests.** Keep them straight-line, DAMP over DRY. A failure message states the expected value, the actual value, and the inputs. [S4]
6. **For a class of inputs, write a property.** Use roundtrip, inverse, oracle, idempotence, or invariant, and assert the strongest one the code supports. Two ways a property asserts nothing: tautology (`add(a,b) == a+b`) and vacuity (an `assume()` that filters out nearly every input). If the code has no algebraic shape, example tests are the honest answer. [S23] Pin a shrunk counterexample with Hypothesis `@example`. Hypothesis also replays saved failures from its example database on every run. [S14]
7. **Snapshots only when small and reviewed.** Jest says to treat snapshots as code, keep them "focused, short, and readable", cap their size with `eslint-plugin-jest` `no-large-snapshots`, and avoid "regenerating snapshots when tests fail without examining root causes". [S15]
8. **Run the mutation check before finishing.** Mutate a constant, a branch, a side effect, the default return, and a validation. If no test fails, the behavior is unprotected or the test is tautological. [S20]

## (c) When not to add a test, and when to delete one

**Bug regression tests.** No credible primary source says outright "do not add a test per bug". Vendor blogs say it ("a typo in an error message doesn't need a permanent regression test"), but they are not primary sources. Google's Beyoncé rule points the other way: "If you liked it, then you shoulda put a test on it". [S3] The rule below is an inference from [S1][S5][S11][S14][S16]. Confidence: medium.

- **Add a test** when the bug's class can plausibly recur: the logic is complicated, the code changes often, or the team has made this mistake before [S1][S16]. Also add one when the cost of a recurrence is high: money, data loss, security, or a customer-facing failure.
- **Test the class, not the instance.** A property or a table over the input domain beats one hard-coded reproduction. Keep the reproduction as an `@example` row inside it, not as a separate test. [S14][S23]
- **Put it at the lowest level that can see the bug.** "If a higher-level test spots an error and there's no lower-level test failing, you need to write a lower-level test." [S5]
- **Add no test** when a type, a constraint, or a lint rule now makes the class impossible. Also add none for a one-off cause: a typo, a config value, or a dependency since fixed upstream. Verify the fix by running it and record it in the RCA.

**Delete:**

- **Change detectors.** These "provide negative value" and "should be re-written or deleted". [S13]
- **High-level tests the lower levels already cover.** Fowler's pyramid article: "I delete high-level tests that are already covered on a lower level", and do not keep them over sunk cost. [S5]
- **Brittle tests**, ones that fail on "an unrelated change to production code that does not introduce any real bugs". [S4]
- **Tests that exist only for a coverage number.** Google's coverage guidance calls them "technical debt from low-value tests". [S17]

**Measure value before pruning.** At Google, of 5.5 million affected tests, only 63,000 ever failed in the period studied, and only 1.23% of executions found a real breakage. Tests "closer" to the code they test fail more often. [S18] That points at the pruning targets: distant, never-failing, slow tests.

**Coverage is a gap report.** In 31,000 generated suites, coverage had a "low to moderate" correlation with effectiveness once suite size was controlled. Coverage "should not be used as a quality target". [S19] Conflict, surfaced: Google's 2020 coverage post calls per-commit coverage of 99% "reasonable" and 90% "a good lower threshold". [S17] I would not adopt that gate for agents. The [S29] study below shows agents already pass presence-based gates with tests that assert nothing, so a coverage gate rewards exactly that.

**Mutation testing measures whether tests catch anything.** At Google, developers shown mutants wrote more and better tests (about 15 million mutants studied), and mutants coupled with real high-priority faults. [S24] It scales by mutating only changed lines at review time, with filtering, across 24,000+ developers. [S25] Tools: Stryker (JS/TS, C#), PIT (JVM), mutmut (Python). Rule: run it on the diff only, and treat a surviving mutant as a missing assertion, not as a target to hit.

## (d) CI speed by rule, not by list

1. **Select tests from the dependency graph.**
   - Vitest: `vitest --changed origin/main`, or `vitest related <files> --run`. Static imports only. [S26]
   - Jest: `--onlyChanged`, `--changedSince=<ref>`, `--findRelatedTests <files>`. Needs a static dependency graph. [S27]
   - Nx: `nx affected -t test` diffs git against the project graph. [S28]
   - pytest-testmon records per-test dependencies with Coverage.py, plus env vars and package versions. [S30]
   - Google TAP runs "all potentially affected tests" from a near-real-time global dependency graph. [S31]
2. **Run small tests presubmit and the rest post-merge.** Presubmit runs "only fast, reliable ones" and catches 95%+ of what the full run would. [S31] Meta's learned selection halved test cost and still reported over 95% of test failures and over 99.9% of faulty changes. [S32]
3. **Give each size a hard budget.** Bazel defaults are 60s small, 300s medium, 900s large, and 3,600s enormous. [S33] Google small tests use one process with no sleep, disk, or network, and medium tests are localhost only. [S3] Matklad prints every test's time by default so outliers are visible. [S12]
4. **Shard what remains:** `--shard=i/n` in Vitest and Jest. [S26][S27]
5. **Quarantine flaky tests automatically, with an owner.** Google: 1.5% of test runs are flaky, almost 16% of tests have some flakiness, and 84% of pass-to-fail transitions involve a flaky test. [S16] At "1% flakiness, the tests begin to lose value". [S3] Slack auto-files a Jira ticket for each flaky test, and an auto-merged PR disables it. Failing test jobs fell from 56.76% to 3.85%. [S34] Expiry is my inference, not something Slack's post states: the quarantine ticket carries a date, and the test is deleted if nobody fixes it by then.

## (e) AI failure modes to guard against

- **Oracles that copy current behavior.** LLM-generated oracles "capture the actual program behaviour rather than the expected one", bugs included. [S35] Guard: derive expectations from the spec or a literal (b4).
- **Tests with no oracle.** In 86,156 test patches from 33,596 agent PRs (Codex, Copilot, Devin, Cursor, Claude Code), 80.2% had weak or no explicit oracle. "Test file counts substantially overestimate verification strength." Strong oracles raised the odds of a merge (OR 1.28). [S29] Guard: reject a test without an assertion on an output or a side effect.
- **Test smells.** LLM suites consistently show Assertion Roulette and Magic Number Test, plus Eager, Lazy, Empty, and Conditional Logic tests. [S36]
- **Tests that do not survive.** At Meta, 75% of generated tests built, 57% passed reliably, and 25% raised coverage. Engineers accepted 73% of what survived the filters. [S37] Guard: keep a generated test only if it passes repeatedly and either kills a mutant or covers a new branch.
- **Mocking the system under test, or asserting on the mock.** "Are we testing the behavior of a mock?" [S20][S21]
- **Tautology and mirror assertions**, such as `expect(add(a,b)).toBe(a+b)` or the same builder on both sides. [S22][S20][S23]
- **Snapshot regeneration on failure.** [S15]

## (f) Companion candidates and local inventory

| Skill | License, size | What it says | Verdict |
|---|---|---|---|
| obra/superpowers `test-driven-development` [S20] | MIT. SKILL.md 9,578 B plus `writing-good-tests.md` 8,268 B. Installed (6.4.1) and already a companion | Name the break, no mirror assertions, no change detectors, never assert on a mock, a mutation check. `testing-anti-patterns.md` was renamed to `writing-good-tests.md` on 2026-07-05 | Keep. Override one line: "Never fix bugs without a test" (SKILL.md:321) contradicts (c) |
| trailofbits `property-based-testing` [S23] | CC-BY-SA-4.0. SKILL.md 4,306 B plus references | Property catalog and strength order. Tautology and vacuity. "Code with no such shape gets example tests" | Install as a companion. Do not copy the text: share-alike would bind Polaris files |
| trailofbits `mutation-testing` [S39] | CC-BY-SA-4.0 | Campaign setup with mewt or muton. Separates equivalent mutants from real gaps | Optional. Mostly Rust, Solidity, and FunC tooling |
| mattpocock `tdd` [S22] | MIT. 3,629 + 2,214 + 1,481 B | Test only at agreed seams, the tautology anti-pattern, vertical slices | Adapt the seam and tautology wording (MIT allows it). Drop "confirm seams with the user", since it costs a turn |
| anthropics `webapp-testing` | Apache-2.0 | Playwright scaffolding, no judgment | Skip. `polaris:playwright-e2e` covers it |

Other testing skills installed locally:

- **Reject, because each one drives test count up:**
  - keel `testing` (MIT, 3,292 B): "every new logic file has a test", plus a patch-coverage minimum.
  - mindrally `testing` (Apache-2.0, 1,959 B): "coverage for every exported function".
  - `clean-tests` (5,552 B, license unknown): "Don't skip trivial tests".
- **Not a source for test judgment:**
  - daymade `qa-expert` (MIT, already a companion) is QA execution.
  - `engineering:testing-strategy` (1,279 B) is too thin to use.

No dedicated, credible "test desiderata" skill exists. GitHub code search finds only mentions inside aggregator registries.

**Polaris already contradicts this research in three places** (Rule 7):

- `rules/clean-code.md` T3 "Keep the trivial test" conflicts with [S1][S5][S8].
- `rules/clean-code.md` T6 "Test exhaustively around a fixed bug" is the exact pattern the user named.
- `commands/debug.md` Phase 6 "Keep the regression test" keeps every test unconditionally. It should apply (c), and it already asks the right question about a guardrail that would prevent the whole class.

## What remains uncertain

- Khorikov's exact wording (paywalled). Resolve with a copy of chapter 4.
- Whether the bug-test rule in (c) cuts suite growth without missing recurrences. Resolve by replaying 6 months of a client repo's fixed bugs against the rule and counting how many recurred.
- Google's two flakiness figures, 1.5% of runs [S16] and about 0.15% [S3], measure different things in different years. Neither is a target.

## Sources

- [S1] Beck, Stack Overflow answer, 2008-09-30. https://stackoverflow.com/a/153565
- [S2] Beck, Test Desiderata. https://testdesiderata.com/
- [S3] SWE at Google, ch. 11. https://abseil.io/resources/swe-book/html/ch11.html
- [S4] SWE at Google, ch. 12. https://abseil.io/resources/swe-book/html/ch12.html
- [S5] Vocke, The Practical Test Pyramid (martinfowler.com, 2018). https://martinfowler.com/articles/practical-test-pyramid.html
- [S6] Khorikov, Unit Testing PPP, ch. 4 (Manning, 2020). https://livebook.manning.com/book/unit-testing/chapter-4, summary at https://notesbylex.com/four-pillars-of-good-unit-tests
- [S7] Dodds, Write tests. https://kentcdodds.com/blog/write-tests
- [S8] Dodds, the 70% figure and full-coverage critique, same post as [S7]
- [S9] Dodds, Testing Trophy. https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications
- [S10] Fowler, Test Shapes, 2021-06-02. https://martinfowler.com/articles/2021-test-shapes.html
- [S11] King, Parse, don't validate, 2019. https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/
- [S12] Matklad, How to Test, 2021. https://matklad.github.io/2021/05/31/how-to-test.html
- [S13] Eagle, Change-Detector Tests Considered Harmful, 2015-01-27. https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html, plus SWE at Google ch. 13 https://abseil.io/resources/swe-book/html/ch13.html
- [S14] Hypothesis API. https://hypothesis.readthedocs.io/en/latest/reference/api.html
- [S15] Jest snapshot best practices. https://jestjs.io/docs/snapshot-testing
- [S16] Micco, Flaky Tests at Google, 2016-05-27. https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html
- [S17] Google, Code Coverage Best Practices, 2020. https://testing.googleblog.com/2020/08/code-coverage-best-practices.html
- [S18] Memon et al., Taming Google-Scale Continuous Testing, ICSE-SEIP 2017. https://research.google/pubs/pub45861/
- [S19] Inozemtseva and Holmes, ICSE 2014. https://cs.ubc.ca/~rtholmes/papers/icse_2014_inozemtseva.pdf
- [S20] superpowers TDD. https://github.com/obra/superpowers/tree/main/skills/test-driven-development
- [S21] keel `testing` skill (local cache, 0.20.0)
- [S22] mattpocock `tdd`. https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd
- [S23] Trail of Bits PBT. https://github.com/trailofbits/skills/tree/main/plugins/property-based-testing
- [S24] Petrović et al., Does mutation testing improve testing practices?, ICSE 2021. https://arxiv.org/abs/2103.07189
- [S25] Petrović et al., Practical Mutation Testing at Scale. https://arxiv.org/abs/2102.11378
- [S26] Vitest CLI. https://vitest.dev/guide/cli
- [S27] Jest CLI. https://jestjs.io/docs/cli
- [S28] Nx affected. https://nx.dev/docs/features/ci-features/affected
- [S29] Banik et al., All Smoke, No Alarm, AITest 2026. https://arxiv.org/abs/2606.18168
- [S30] pytest-testmon. https://testmon.org/
- [S31] SWE at Google, ch. 23. https://abseil.io/resources/swe-book/html/ch23.html
- [S32] Machalica et al., Predictive Test Selection, 2019. https://arxiv.org/abs/1810.05286
- [S33] Bazel Test Encyclopedia. https://bazel.build/reference/test-encyclopedia
- [S34] Patel, Slack, 2022-04-05. https://slack.engineering/handling-flaky-tests-at-scale-auto-detection-suppression
- [S35] Konstantinou et al., 2024. https://arxiv.org/abs/2410.21136
- [S36] Ouédraogo et al., test smells in LLM tests, 2024. https://arxiv.org/abs/2410.10628
- [S37] Alshahwan et al., TestGen-LLM, FSE 2024. https://arxiv.org/abs/2402.09171
- [S39] Trail of Bits mutation-testing. https://github.com/trailofbits/skills/tree/main/plugins/mutation-testing
