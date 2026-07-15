---
description: The bug lifecycle: interview, ground in the code and stack, reproduce, find root cause, fix, verify, prevent
argument-hint: "<the bug or symptom>"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write, WebFetch, WebSearch
---

# Polaris bug lifecycle

Take the bug in `$ARGUMENTS` from symptom to a verified root-cause fix with a regression test. This
is the counterpart to `/flow`, for bugs. It never patches a symptom, and it confirms the diagnosis
before fixing. Read `.polaris/config.json` first and honor it.

## Phase 0 — Intake interview

Interview until nothing critical is unknown. Ask, and do not proceed on a guess:

- The symptom and the expected behavior. What actually happens versus what should.
- Exact reproduction steps, or "we cannot reproduce it reliably" (that is itself a finding).
- When it started and what changed then (a deploy, a data change, a dependency bump).
- Frequency: always, intermittent, one user or many, one environment or all.
- Severity and blast radius: who and what is affected, is money or data at risk.
- The evidence: error messages, stack traces, logs, and the request or input that triggered it.
- The data and config involved. Ask for the relevant DB schema and any feature flags or settings.

Batch the questions so the user answers once. If the user cannot answer some, record them as
unknowns to resolve during grounding.

## Phase 1 — Ground

Build a real model of the system, not a guess from memory:

- Scan the codebase for the paths the symptom implicates and read them. Trace the actual control
  and data flow through the code, top to bottom.
- Detect the stack and version, and fetch fresh docs via the docs protocol (`llms.txt` first) for
  the framework and any library in the failing path.
- Load the DB schema and the config the bug touches (dispatch `data-modeler` when the schema is
  central). Confirm the assumptions the code makes about the data actually hold.

## Phase 2 — Reproduce

Get a reliable reproduction and capture it as a failing test at the right level (unit for logic,
integration or e2e for a flow), using `systematic-debugging`. Confirm the test fails for the real
reason. A bug you cannot reproduce is not yet understood; keep grounding until you can, or narrow
the conditions under which it happens.

## Phase 3 — Root-cause analysis

Form competing hypotheses and test each against the code and the reproduction; try to refute each.
Find the actual cause, then name the class of bug: a rounding rule in the wrong place, a missing
guard on a whole category, an off-by-one on a shared boundary, a race on a shared write, a timezone
assumption, state mutated where it should be derived. **Stop and confirm the diagnosis with the
human before fixing.**

## Phase 4 — Fix

Dispatch `bug-fixer`: fix the logic so the whole class cannot recur, not just the reported case. No
hardcode, no special-case branch for the test input, no hacky patch, no anti-pattern, no widened
type to silence a symptom. Prefer making the bad state unrepresentable. Run the quality gate.

## Phase 5 — Verify

Dispatch `verifier`: confirm the reproduction now passes and no regression appeared, by exercising
real behavior. Check the named class does not occur elsewhere in the code; if it does, fix those
too. Loop until clean, capped at 3 rounds; on non-convergence, stop and report the state.

## Phase 6 — Prevent and report

Keep the regression test. Note where else the class could appear and whether a guardrail (a type, a
constraint, a validated entry point) would prevent the whole class. Write an RCA to
`.polaris/reports/<date>-bug-<topic>-rca.md`: the symptom, the root cause, the class, the fix, and
the prevention. Record a memory entry so the class is remembered across sessions.

## Rules

- Confirm the diagnosis before the fix. Never fix a bug you have not reproduced and understood.
- Fix the class, not the case. A fix that makes the test green while the cause survives is not a fix.
- Every emitted line passes the quality gate and the writing standard. Evidence before claims.
