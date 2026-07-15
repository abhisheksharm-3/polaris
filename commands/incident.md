---
description: Production incident to postmortem: triage, stabilize, find the cause, fix, write a blameless postmortem
argument-hint: "<the alert or incident description>"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write, WebFetch, WebSearch
---

# Polaris incident response

Handle the production incident in `$ARGUMENTS`, often from an alert. Stabilization outranks a
perfect fix: stop the bleeding first, fix the cause properly after. Read `.polaris/config.json`
first and honor it. Nothing outward-facing (a deploy, a rollback, a status post) happens without
confirmation unless the config authorizes it.

## Phase 0 — Triage and assess

Establish what is happening and how bad it is: the symptom, the blast radius (who and what is
affected), whether money or data is at risk, and when it started. Pull live context from `sre`
observability (logs, metrics, traces) and from the connectors when available (the alert, recent
deploys, related tickets). Set a severity.

## Phase 1 — Stabilize

Stop the harm before diagnosing the root cause. Prefer the fastest safe mitigation: roll back the
recent deploy, disable the feature flag, drain the bad instance, or add a rate limit. Confirm the
mitigation before applying it unless the config authorizes autonomous action. Verify the harm has
stopped before moving on.

## Phase 2 — Find the cause

Run the `/debug` root-cause path on the underlying cause: ground in the code and the stack, reason
from the evidence and a reproduction where one is possible, form and refute competing hypotheses,
and name the class of failure. Correlate with the deploy or data change that triggered it.

## Phase 3 — Fix and verify

Dispatch `bug-fixer` for the root-cause fix (fix the class, no hacky patch), then `verifier` to
confirm it holds and introduces no regression. Ship it through the normal gate; do not weaken a
check to expedite.

## Phase 4 — Postmortem

Write a blameless postmortem to `.polaris/reports/<date>-incident-<topic>-postmortem.md`: the
timeline, the impact, the root cause and its class, the mitigation and the permanent fix, and the
follow-up actions (the guardrail, alert, or test that would have caught it sooner). Record a memory
entry. The postmortem blames the system and the gaps, never a person, and passes the writing
standard.

## Rules

- Stabilize before you diagnose; a perfect fix an hour into an outage is the wrong priority.
- Confirm anything irreversible or outward-facing before doing it.
- Tell the whole truth in the postmortem, including what was not known and what got lucky.
