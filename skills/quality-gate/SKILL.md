---
name: quality-gate
description: Use to check or fix code and prose against the Polaris standard before work is called done: a quality pass, slop removal, a self-check before commit or PR, or verifying a changeset. Runs a deterministic pass plus a judgment pass and reports pass/fail with file:line findings and fixes. Trigger phrases include "run the gate", "quality check", "check this before I push", "remove slop", "is this up to standard".
---

# Quality Gate

The single engine that enforces the Polaris standard. Every agent and the orchestration cycle
call this before declaring work done. It reads one standard so a rule changes everywhere at once.

## Inputs

- Default: the current changeset (`git diff --name-only` plus staged and unstaged files).
- Explicit paths when given.
- "The code just written" when invoked right after generation.

## Modes

- `--check` (default): report only, do not modify.
- `--fix`: apply fixes, then re-run to confirm green.
- `--scope code|writing|both` (default `both`).

## Steps

1. **Resolve and detect.** Resolve the files in scope. Detect the stacks present from manifests
   and file extensions. Load `${CLAUDE_PROJECT_DIR}/.polaris/config.json`; if absent, use the
   greenfield defaults (`deadCode: delete`, `backwardCompat: none`).

2. **Load resources.** For each detected stack, read `rules/stack-map.json` and load: the host
   skill(s) named there, fresh docs per the core docs protocol (`llms.txt`, then version docs,
   then search), the Polaris overlay if one exists, and the relevant slice of `rules/patterns.json`.
   Always load `rules/core.md` and `rules/writing.md`.

3. **Mechanical pass.** Run the deterministic checker over the changeset:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/check-patterns.sh" <scope> <files...>
   ```
   Collect its `file:line: rule: message` findings. Fast and high-confidence: banned words, em-dash
   spray, `as any`, `@ts-ignore`, `console.log`, `TODO`.

4. **Judgment pass.** Read the diff against `core.md`, `writing.md`, and the loaded overlays and
   skill guidance. Judge what a regex cannot: root-cause versus symptom, one-file-one-
   responsibility, defensive checks in trusted paths, naming clarity, architecture leaks,
   duplication, and slop the checker does not encode.

5. **Apply the config.** Adjust by `.polaris/config.json`:
   - `backwardCompat: "maintain"` — do not flag compat shims or aliases.
   - `deadCode: "keep"` — orphan and dead-code findings are notes, not failures. `"flag"` reports
     them without auto-fixing.
   - `architecture` / `naming` — judge against the project's rules or mirrored reference, not the
     Polaris defaults, when the config sets them.

6. **Report or fix.**
   - `--check`: print pass/fail and every finding as `severity | file:line | rule | fix`.
   - `--fix`: apply the fixes (root-cause, never a hacky patch), then re-run the mechanical pass to
     confirm green. Report what changed.

## Output shape

```
Quality gate: FAIL (3 findings)
- high   | src/actions/order.ts:42 | as-any        | extract OrderInputType and type the param
- medium | src/OrderList.tsx:12    | use-effect-fetch | replace with a React Query hook
- low    | commit message          | banned-word:leverage | use "use"
```

A clean run prints `Quality gate: PASS`.

## Notes

- The mechanical checker skips `rules/` and `patterns.json` (they hold the banned patterns as data).
- Never weaken a check to make it pass. Fix the code, or report the finding.
