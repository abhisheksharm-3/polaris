# Slice: Diagnostic and Operational Modes — Design Spec

Date: 2026-07-15. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` (subsystems D, G). Depends on A, B, the fleet, memory.

The feature cycle (`/flow`) is strong for building. Bugs need their own lifecycle, and a few other
recurring jobs deserve a mode that rides the same infrastructure. This slice adds them.

## Problem

Bugs arrive often and are handled ad hoc: guess, patch, hope. There is no interview-driven,
grounded, root-cause bug lifecycle the way there is for features. The same is true for production
incidents, dependency upgrades, and security hardening, each a recurring job with a known shape.

## Goal

A `/debug` bug lifecycle, interview-driven and grounded, plus `/incident` for production incidents.
Each reuses the fleet, the gate, the guardrails, memory, and the docs protocol. Design two more
(`/modernize`, `/harden`) and note them for later.

### Success criteria

- `/debug <symptom>` runs an intake interview, grounds itself in the code and stack, reproduces the
  bug, finds the root cause and its class, fixes it, verifies, adds a regression test, and writes an
  RCA. It never patches a symptom, and it gates the diagnosis behind confirmation.
- `/incident <alert>` triages a production incident, stabilizes, finds the cause, fixes, and writes a
  postmortem.
- Both commands reference only real agents and pass the writing standard.

## Architecture

### `/debug` — the bug lifecycle

`commands/debug.md`. The counterpart to `/flow`, for bugs. Phases:

1. **Intake interview** (the bug equivalent of the product interview). Ask, until nothing critical
   is unknown: the symptom and expected behavior, exact reproduction steps, when it started and what
   changed then, frequency (always, intermittent, one user), environment, severity and blast radius,
   the error messages and logs, and the data involved. Ask for the DB schema and any config the bug
   touches. Do not proceed on a guess.
2. **Ground.** Scan the codebase for the paths the symptom implicates and read them. Detect the
   stack and fetch fresh docs via the docs protocol (`llms.txt` first). Load the DB schema and the
   relevant config. Build a grounded model of how the code actually flows, not a guess from memory.
3. **Reproduce.** Get a reliable reproduction and capture it as a failing test at the right level.
   A bug you cannot reproduce is not yet understood. (Uses `systematic-debugging`.)
4. **Root-cause analysis.** Form competing hypotheses and test each against the code and the
   reproduction; try to refute each. Find the actual cause and name the class of bug (a rounding
   rule in the wrong place, a missing guard on a category, an off-by-one on a shared boundary, a
   race, a timezone assumption, state mutated where it should be derived). **Confirm the diagnosis
   with the human before fixing.**
5. **Fix.** Hand to `bug-fixer`: fix the logic so the whole class cannot recur, no hardcode, no
   hacky patch, no anti-pattern. Run the gate.
6. **Verify.** `verifier` confirms the reproduction now passes and no regression appeared; check the
   class does not appear elsewhere in the code. Loop until clean, capped.
7. **Prevent and report.** Keep the regression test. Note where else the class could occur. Write an
   RCA to `.polaris/reports/<date>-bug-<topic>-rca.md`: symptom, root cause, the class, the fix, and
   the prevention. Record a `working`/`project` memory entry so the class is remembered.

Grounding is the difference from a generic debugger: real stack docs, the real DB schema, the real
code path, and a real reproduction before any fix.

### `/incident` — production incident to postmortem

`commands/incident.md`. For a live or recent production incident (often from an alert). Phases:
triage and assess blast radius; stabilize (mitigate or roll back first, fix properly after); pull
context from `sre` observability and the connectors when available; run the `/debug` root-cause path
on the cause; fix and verify; write a blameless postmortem to `.polaris/reports/` with a timeline,
the cause, the fix, and the follow-ups. Stabilization outranks a perfect fix.

### Designed, built later

- **`/modernize`** — dependency and framework upgrades: read the changelog and migration guide via
  the docs protocol, upgrade, run the migration codemods, fix breakages via `bug-fixer`, verify.
- **`/harden`** — a security pass: `security-architect` threat-models the surface, `reviewer`
  (security lens) and a pentest sweep find issues, `bug-fixer` closes them, `verifier` confirms.

## Testing and validation

- Commands reference only agents in `agents/`; the command-reference check covers `flow.md` and
  extends to these. Both pass `check-patterns.sh prose`.

## Out of scope

- New agents (these orchestrate the existing fleet).
- `/modernize` and `/harden` implementation (designed here, built later).
