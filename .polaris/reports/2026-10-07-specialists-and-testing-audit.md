# Specialists and testing audit

Date: 2026-10-07. Run: audit-1007. Scope: every specialist agent no flow reaches, and everything
Polaris says or does about tests. The design engine audit (2026-09-30) found design had agents and no
engine; this finds the same shape for a dozen more domains, and for testing an engine that points
the wrong way.

## Part A: specialists nothing reaches

14 of 27 agents appear in no flow phase. Measured with `scripts/route-prompt.sh`: 13 of 21 realistic
prompts in their domains route to `unknown` (9) or to a generic `feature` (4).

| Domain | Agent | Reached today | Prompt that misroutes |
|---|---|---|---|
| Schema and migrations | data-modeler | named inside `/debug` prose | "add a migration to split the users table" -> feature |
| Production readiness | prod-audit | nothing | "is this ready for production" -> unknown |
| Deploy and CI | devops | build Split only | "deploy this to staging", "set up ci" -> unknown; "the build is failing on ci" -> bug |
| Observability | sre | named inside `/incident` | "add monitoring and alerts" -> unknown |
| API contracts | api-designer | nothing | "design the api for the orders service" -> unknown |
| Security at design time | security-architect | `security` flow only | a feature adding a public endpoint gets no threat model |
| Performance | perf | review dimension only | "this endpoint is slow under load" -> unknown |
| Third-party integrations | integrations | build Split only | "integrate stripe checkout and the webhook" -> unknown |
| End-to-end tests | e2e | named inside `/debug` | "write e2e tests for the signup flow" -> unknown |
| Infrastructure | infra | build Split only | "containerize this app", "set up terraform" -> unknown |
| Data pipelines | data-engineer | build Split only | "build an etl for analytics events" -> feature |
| i18n, SEO, offline, mobile | none | none | four prompts -> feature or unknown |

### Findings

- **S1 (high).** A migration, the least reversible change Polaris makes, runs as a generic feature
  with no reversibility, backfill, or lock check.
- **S2 (high).** `ship` and `release` have no readiness, deploy, rollback, or observability step.
  prod-audit is dispatched by nothing.
- **S3 (high).** `feature` has no contract phase and no design-time threat model. api-designer, a
  written opus agent, is dispatched by nothing.
- **S4 (medium).** Performance has no measure-fix-remeasure flow and no number as evidence.
- **S5 (medium).** Integrations and e2e have agents and no route or flow.
- **S6 (medium).** CI, infra, i18n route to unknown or a generic feature.
- **S7 (cost).** Adding a phase to `feature` costs an approval on every feature. The catalog has no
  conditional phase, so a phase that applies to some features must be either always-on or absent.

## Part B: testing

Research with 38 cited sources: `.polaris/reports/2026-10-07-testing-research.md`. The user's
problem, in their words: AI writes no tests, or tests "for cases that were one off or will never
happen", and that is how a team reaches 30k tests and two-hour CI.

### Findings

- **T-1 (high). Polaris teaches the habit it should stop.** `rules/clean-code.md` T3 "Keep the
  trivial test" and T6 "Test exhaustively around a fixed bug"; `commands/debug.md` Phase 6 "Keep the
  regression test" with no condition; `agents/bug-fixer.md` requires a reproducing test for every
  bug and keeps it. The superpowers companion adds "Never fix bugs without a test" (SKILL.md:321).
  Every bug therefore leaves a permanent test for its instance, which is the 30k-test mechanism.
- **T-2 (high). No one owns the suite.** tester breaks the feature by hand and leaves nothing
  durable. e2e writes durable tests and nothing dispatches it. No agent decides what to test, at
  which level, or what to delete.
- **T-3 (high). Nothing judges a test.** The gate has no test check, mechanical or judgment. Review's
  `tests` dimension asks only what is uncovered, never what is excess, so review only grows the suite.
  80% of agent-written test patches have a weak or missing oracle (Banik et al. 2026, S29).
- **T-4 (medium). Preloads push count up.** tester and bug-fixer preload mindrally `testing`
  ("coverage for every exported function"). keel `testing` and `clean-tests` say the same.
- **T-5 (medium). No CI-by-rule guidance.** Nothing tells devops to select tests from the dependency
  graph, budget test sizes, or quarantine flakes with an owner and an expiry. The user's sage memory
  already rules: "select by a rule, never by an enumeration".
- **T-6 (low). Polaris's own suite** is 406 assertions in one 2,042-line file, 37 s. Healthy size,
  but one file means no selective run.

## Proposal

### Engine: conditional phases (fixes S7 and the experience-phase cost)

The product agent's spec declares one line, `Surfaces: ui, api, data, auth, integration, none`
(a classification, which is model work). A phase may carry `"when": "<surface>"`; `run-state.sh`
skips it, and records the skip as `skipped`, when the recorded spec does not declare that surface.
Routing stays code. `experience` becomes `when: ui`, so a backend feature no longer stops for ux.

### Specialists

| Change | Phases |
|---|---|
| `feature` gains conditional phases | spec, experience (ui), contract: api-designer (api), schema: data-modeler (data), threat-model: security-architect (auth, api, integration), design, build, ship |
| New `migration` flow | plan: data-modeler (approve: reversibility, backfill, locks), build, verify, ship |
| New `readiness` flow | audit: prod-audit (approve), observe: sre, deploy: devops (rollout and rollback), ship |
| New `perf` flow | measure: perf (a baseline number), fix: specialist, remeasure: perf (the number again) |
| New `integration` flow | contract: integrations (approve: idempotency, signatures, retries), build, verify, ship |
| New `platform` flow | change: devops or infra, gate, ship |
| Routing classes for each, with fixtures | the 13 misrouted prompts plus negatives |
| A `migration` pattern class | `DROP TABLE`, `DROP COLUMN`, `ALTER ... TYPE`, `NOT NULL` without a default, flagged for review |

i18n and SEO become `ui` surface concerns under `rules/design.md`. Mobile has no agent; see the
decisions below.

### Testing engine

1. **`rules/testing.md`**, the full standard from the research: decide before writing (name the
   break, recurrence and cost, a type over a test, the level by confidence per cost), how to write
   (public seam, state over interaction, real then fake then stub then mock, an oracle derived
   without the code, no logic, a property for a class of inputs, small reviewed snapshots), when not
   to add and when to delete (the bug rule, change detectors, duplicates covered lower, brittle and
   coverage-only tests), size budgets, CI by rule, and the AI failure modes.
2. **`rules/testing-core.md`** under 3,000 bytes, injected every session by its own hook and into
   every code-writing subagent, the way design-core is.
3. **The bug rule replaces the reflex.** A bug earns a test for its class, at the lowest level that
   sees it, only when the class can recur or the cost is high and no type, constraint, or lint can
   rule it out; the reproduction becomes an example row inside it. A typo or a config value earns
   none. Rewrite T3 and T6, `/debug` Phase 6, and bug-fixer; state the override of the superpowers
   line in `rules/testing.md` (Rule 7).
4. **A `test-engineer` agent owns the suite**: the test plan per change (what, at which level, what
   to delete), durable tests, pruning, and CI selection. tester stays the adversarial breaker; e2e
   stays the browser specialist and becomes reachable.
5. **A `testing` flow and `/polaris:test`**: survey (count, time, slowest, never-failing, flaky,
   change detectors; approve), plan, write or prune, prove (each new test fails when its named break
   is introduced; a mutation run on the diff when Stryker, PIT, or mutmut is installed), gate.
   Routing: "write tests for", "prune the tests", "ci is slow", "flaky test", "e2e tests for".
6. **Build and qa hold the line.** Each build slice's done names its tests and the break each
   catches; `qa` gains a `pin` phase where test-engineer decides which breaks earn a durable test.
7. **Review and gate judge tests both ways.** The review `tests` dimension asks what is missing and
   what is excess. A `test` pattern class catches committed `.only`, unexplained `.skip`, fixed
   sleeps (`waitForTimeout`, `sleep(`), and `expect(true)`-style tautologies.
8. **Companions.** Drop mindrally `testing` from tester and bug-fixer. Add trailofbits
   `property-based-testing` as a companion (CC-BY-SA-4.0, so installed, never copied).
