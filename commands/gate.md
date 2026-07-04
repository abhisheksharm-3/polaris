---
description: Run the Polaris quality gate on the current changeset (check or fix, code and prose)
argument-hint: "[--fix] [--scope code|writing|both]"
---

Invoke the `quality-gate` skill on the current changeset.

Arguments passed by the user: `$ARGUMENTS`

- Default is `--check --scope both`.
- Pass `--fix` to apply fixes and re-verify.
- Pass `--scope code`, `--scope writing`, or `--scope both` to narrow what is checked.

Follow the `quality-gate` skill exactly: resolve the changeset, detect stacks, load the standard
and config, run the mechanical pass via `scripts/check-patterns.sh`, run the judgment pass, then
report pass/fail with `file:line` findings, or apply fixes when `--fix` is set.
