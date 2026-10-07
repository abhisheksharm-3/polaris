# Polaris core testing standard

<!-- Injected every session by hooks/inject-cores, and into every code-writing subagent by -->
<!-- inject-standard, so test judgment has the standing code and design have. Budget: 3,000 -->
<!-- bytes. The full standard, with sources, is rules/testing.md. -->

A test is a cost paid on every run for the life of the code. Write the smallest suite that gives
confidence to change the code. Thousands of one-off tests and a two-hour CI are the failure.

1. **Name the break first.** Before writing a test, write the production change that should turn it
   red. No nameable bug-shaped break, no test. A test that fails on a deliberate change is a change
   detector: delete it.
2. **A type before a test.** If a type, a constraint, a parser, or a lint rule can make the bad state
   impossible, do that and write no test for the instance.
3. **The bug rule.** A fixed bug earns a test only when its class can recur or a recurrence is
   expensive (money, data, security, customers), and nothing above can rule it out. Then test the
   class, a table or a property with the reproduction as one row, at the lowest level that sees it.
   A typo, a config value, or a one-off cause gets a verified fix and no permanent test.
4. **Behavior through the public seam.** Mostly integration tests with real collaborators where
   fast; mock only the process boundary. Assert outputs and state, not calls. Never mock the subject.
5. **An oracle not built by the code.** The expected value is a literal or a hand-checked fixture.
   No logic in tests.
6. **Prove it can fail.** Introduce the named break, watch it go red, restore. A test that stays
   green is deleted.
7. **Deterministic and fast.** No fixed sleeps, frozen clock, seeded randomness, own data. Small
   tests under 100 ms. Coverage is a gap report, never a target.
8. **CI selects by rule.** Changed-file and dependency-graph selection, never a hand-kept list.
   Flaky tests are quarantined with an owner and an expiry.

Test work routes to the `testing` flow (`/polaris:test`), owned by the test-engineer agent. Load
`rules/testing.md` before writing, reviewing, or pruning any test.
