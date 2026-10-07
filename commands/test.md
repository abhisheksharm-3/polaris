---
description: Open the testing flow: survey a suite, plan what earns a test and what to delete, then write, prune, and prove
argument-hint: "<what to test, or the suite or CI problem: 'tests for billing', 'ci takes 2 hours', 'flaky e2e'>"
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

# Test

Open the `testing` run for the task in `$ARGUMENTS` and start it. The flow is the `testing` row in
`rules/flows.json`; the ledger and the gates enforce it. `hooks/enhance-prompt` opens the same run
for a described testing task, so this is the explicit door to the same room.

## Steps

1. Read `.polaris/config.json`.
2. Open the run: `${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh seed testing <slug>`, with a slug drawn
   from the task. It refuses when this session already has a run open; `/polaris:pause` clears it.
3. Say which phases the run holds and which stop for approval:
   `jq -r '.testing.phases[] | "\(.name) -> \(.run)"' "${CLAUDE_PLUGIN_ROOT}/rules/flows.json"`.
4. Run the first phase. Dispatch `test-engineer` in survey mode with the task: it measures the suite
   (count by level, total and slowest times, skipped, flaky across three runs, change detectors,
   duplicates, assertion-free tests) and writes the plan of what to add, at which level and with
   which named break, and what to delete under which rule.
5. Record it: `scripts/run-state.sh record survey <plan path> "<counts and times, adds, deletes>"`.
6. Present the plan and stop. `survey` carries an approval.

From there `advance-flow` names each phase: test-engineer (or e2e for browser journeys) writes and
prunes, the verifier proves each new test fails on its named break, and the gate runs with its test
pattern class.

## Rules

- `rules/testing.md` decides what earns a test. More tests is not the goal; confidence per second of
  CI is.
- Approval phases are hard stops. Never stamp an approval on the human's behalf.
- Deleting tests is the point as often as adding them. Every deletion names its rule.
