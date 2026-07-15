# RCA: session-start startup error and 30s hang

Date: 2026-07-16. Trigger: `/debug`. Two related defects in the session-start path, both found and
fixed. Severity: high for reach (every session on affected machines), low for data risk (no data
loss; the hook is non-blocking).

## Symptom

- `SessionStart:startup hook error ... hooks/session-start: line 131: detected_stacks[@]: unbound variable`.
- Claude Code unresponsive for about 30 seconds at startup.

## Bug A — empty-array crash

**Root cause.** Line 131 expanded `"${detected_stacks[@]}"` under `set -u`. On bash 3.2 (the macOS
default, confirmed 3.2.57) an empty array `[@]` expansion under nounset raises "unbound variable",
and with `set -e` the hook aborts. It fires in any project with no detected stack (no
`package.json`, `pyproject.toml`, `Cargo.toml`, or `go.mod`), Polaris's own repo included.

**Class.** Unguarded empty-array `[@]` expansion under `set -u` on bash 3.2.

**Blast radius.** The whole session-start injection (core standard, writing rule, memory index,
stack rules) fails to load. Non-blocking, so the session continues without any Polaris context.

**Fix.** Guard the loop with `if [ ${#detected_stacks[@]} -gt 0 ]`. Committed `ca94154`.

**Class swept.** The one other `"${arr[@]}"` in the hooks and scripts, `check-commands.sh:36`, is
preceded by `[ -n "$line" ] || continue`, so its array is never empty at the loop. Not vulnerable.

## Bug B — 30s startup hang

**Root cause.** `ensure-companions.sh` runs on every session start and re-ran `claude plugin
marketplace add` and `claude plugin install` for every companion each time, with no marker guard.
Only the skill-bulk git clone below it was guarded. Each `claude` call spawns the CLI and touches
the network; the whole set measured 28.2s on a fresh run and 8.5s warm, on every start.

**Class.** An expensive, idempotent-in-effect setup step re-run on every session start instead of
once.

**Fix.** Marker-guard the plugin-install block with `.polaris-companions-installed`, matching the
skill-bulk pattern. Second and later runs measured 0.010s. Committed on 2026-07-16. Delete the
marker to re-sync after editing `companions.json`.

## Verification

- `session-start` exits 0 in a no-stack directory (was exit 1 on the cached build).
- `ensure-companions` invokes the `claude` CLI on the first run and skips it once the marker
  exists, proven with a stubbed `claude` on `PATH`.
- Both are pinned by new regression tests in `tests/run-tests.sh`.

## Prevention

- Regression tests added for both classes.
- Any future `"${arr[@]}"` in a `set -u` script needs a length guard or the `${arr[@]+"${arr[@]}"}`
  idiom while bash 3.2 is a target.
- Any per-start setup step must be marker-guarded or otherwise cheap; startup is on the critical
  path of every session.

## Propagation note (why the fixes are not live yet)

The failing hook runs from the installed plugin cache at
`~/.claude/plugins/cache/polaris-marketplace/polaris/1.2.0/`, which is stale relative to this repo.
Both fixes are committed here but do not reach a running session until the installed plugin is
updated. Hand-editing the cache is disallowed (it is a package-managed directory). The remedy is a
version bump and a plugin update, not a cache edit.
