---
description: Security hardening pass: threat-model the surface, find issues, fix them, verify
argument-hint: "[area or feature to harden, or the whole app]"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write, WebFetch, WebSearch
---

# Harden

Run a security pass over `$ARGUMENTS`. This is authorized defensive review of the owner's own code;
go deep. Read `.polaris/config.json` first.

## Steps

1. **Threat model.** Dispatch `security-architect` to map the attack surface and trust boundaries
   and enumerate the threats per boundary (broken authorization and IDOR, injection, tampering,
   replay and races, secret and PII exposure, auth and session, availability).
2. **Find.** Dispatch `reviewer` with the security lens across the surface, and `tester` for an
   active sweep: swap ids to reach another tenant's data, tamper with amounts and roles, inject the
   classic attack strings, replay requests, feed hostile and oversized input. Collect findings with
   `file:line` and severity.
3. **Verify each finding.** Dispatch `verifier` to confirm each is real and reachable, and to drop
   the false positives with a note. Keep only what survives.
4. **Fix.** Hand confirmed findings to `bug-fixer`: close the class at its source, fail closed, add
   the missing authorization check, parameterize the query, add the idempotency key. Run the gate.
5. **Confirm.** Re-verify each fix holds and introduces no regression. Loop until the surface is
   clean, capped.
6. **Report.** Write the result to `.polaris/reports/<date>-harden-<topic>-report.md`: the threats,
   the findings, the fixes, and the residual risk. Never weaken a check to pass.

## Rules

- Fail closed, not open. The safe default is off.
- Money and identity paths get idempotency and server-side verification, always.
- Tell the whole truth about residual risk.
