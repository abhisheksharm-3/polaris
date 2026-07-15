# {{topic}} — Prod-Readiness Audit Handoff (read every line)

> To the thread picking this up: this is not a routine review. The owner cannot review
> {{surface_size}} themselves and is trusting this audit as the last line of defense before real
> users depend on it. Treat every unverified path, every unhandled edge case, every silent failure
> as a production incident waiting to happen. Do not hand-wave. Do not assume. Do not call anything
> fine that you have not proven fine with evidence. If unsure, dig until sure.

## 0. The standard (non-negotiable)

Every file this work created or touched must read as something a senior engineer would ship and an
auditor would find self-explanatory:

- **Correct and complete.** Every flow and every state a user, admin, or webhook can reach, and
  every edge case (empty, zero, negative, huge, null, non-integer, concurrent, retried,
  out-of-order, partial-failure, terminal, race) is handled deliberately.
- **Secure.** No broken authorization, no IDOR, no injection, no secret or PII leak, no amount
  tampering, no missing idempotency, correct access control, fail-closed not fail-open.
- **Performant and cost-aware.** No N+1 in hot paths, no unbounded loops, pagination handled, no
  query that gets slow at volume.
- **Clean and maintainable.** The simplest correct implementation. No hacky patches, no
  anti-patterns, no defensive cargo-culting, no dead code. A new engineer understands each file cold.
- **Gate-compliant.** Passes the Polaris quality gate honestly, never by weakening a threshold.

Hard constraint: audit only code created or changed by this work. Log pre-existing issues; do not
fix them.

## 1. What this is and the audit surface

{{what the work is, in a paragraph}}

Audit surface: {{the exact diff command and file/line count, for example
`git diff <base>...<branch>`}}. Get the exact current list before starting.

## 2. Start here (read these first, in order)

{{memory entries, specs, config, and harness files to read before auditing, in order}}

## 3. Remaining work to finish first

{{any planned work not yet done; finish it TDD-first, then audit. "none" if the surface is complete.}}

## 4. The audit method (be exhaustive, not performative)

Use the multi-agent adversarial method; one reviewer cannot hold the whole surface. Dispatch
independent per-subsystem reviewers, each with correctness, security, performance, and clean-code
lenses. Verify every finding by trying to refute it. Loop until a full pass finds nothing new.

Subsystems to cover: {{list the subsystems in this surface}}.

High-risk items to re-verify end to end: {{the specific risks prior review or the domain surfaces}}.

## 5. Skills to load

{{the stack and review skills to load; survey the full skill list for more}}

## 6. Known landscape and locked decisions

{{gotchas, base-branch notes, and decisions already locked that must not be reversed silently}}

## 7. Working rules

Commit straight onto the branch. TDD always, watch tests fail first. Checkpoint-commit every few
files. Never bypass the gate. Evidence before claims: run the command, show the output; never
assert passing or fixed or done you have not just verified.

## 8. Definition of done (all true, with evidence)

{{checkbox list: remaining work implemented and reviewed; a fresh adversarial multi-agent audit
finds zero unresolved Critical or High and every Medium fixed or accepted with rationale; the gate
is green; a final written report states what was found, what was fixed, what is accepted with
rationale, and a blunt statement of residual risk}}

Take your time. Do not skip, do not hand-wave, do not declare done what is not proven.
