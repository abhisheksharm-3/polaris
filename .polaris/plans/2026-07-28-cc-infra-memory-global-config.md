# Plan — deterministic capture, prompted global config, least privilege

> Implements `.polaris/specs/2026-07-28-cc-infra-memory-global-config-spec.md`, with the approved
> scope: the `Stop` hook covers journal enrichment, tracker reconcile, and memory capture; the
> least-privilege pass runs in this run.

## Slice order

Five slices. Slice 1 is independent and ships the live bug fix. Slice 2 is the substantive change.
Slices 4 and 5 are mechanical and run after the behavior is verified.

---

### Slice 1 — Fix the stale sweep paths

**Files:** `commands/journal.md`, `scripts/journal-facts.sh`

1. `scripts/journal-facts.sh:90` — replace `"$cwd/.polaris/work/sweep-state.json"` with
   `"${HOME}/.claude/polaris-memory/sweep/state.json"`. The path no longer varies per project, so the
   surrounding per-project loop reads one shared state file.
2. `commands/journal.md:29` — `timezone` resolves from sweep's config, not `.polaris/config.json`.
3. `commands/journal.md:33` — `sources` resolves from `~/.claude/polaris-memory/sweep/config.json`.
4. `commands/journal.md:37,39` — state and `notionParentPageId` resolve from the user-level paths.

**Verify:** `grep -rn 'sweep\.\|sweep-state' commands/journal.md scripts/journal-facts.sh` returns no
project-relative hit. Run `bash scripts/journal-facts.sh 2026-07-27 hook` and confirm it exits 0 and
emits markdown.

---

### Slice 2 — `hooks/stop-capture` and the `Stop` wiring

**Files:** `hooks/stop-capture` (new), `hooks/hooks.json`, `hooks/session-start`

The hook is the whole point of the change, so it gets the most care.

1. **Write `hooks/stop-capture`.** Reads the hook JSON on stdin. Order of operations:
   - `jq -r '.stop_hook_active'` — if `true`, `exit 0` immediately. Documented loop-breaker.
   - Per-session marker at `${TMPDIR:-/tmp}/polaris-stop-capture/<session_id>`. If it exists,
     `exit 0`. Follows the `guard-edit` and `guard-review` precedent.
   - Collect outstanding work into a reason string:
     - **Journal:** every `~/.claude/polaris-memory/journal/*.md` whose frontmatter says
       `status: facts`. List at most 5 by name plus a total count, to stay well inside the
       10,000-char output cap.
     - **Tracker:** if `.polaris/work/` exists, read `.last-reconciled.local` and run
       `scripts/worktracker-snapshot.sh "$PWD" "$since"`. Include the snapshot only when non-empty.
     - **Memory:** included in the reason whenever the hook blocks for either reason above. No new
       shell heuristic for "memory-worthy" — a session with journal or tracker work outstanding is by
       definition a session that did something, and the model judges what is worth saving against the
       bar in `rules/memory.md`.
   - If nothing is outstanding, `exit 0` silently. A trivial one-question session never blocks.
   - Otherwise write the marker, then emit `{"decision":"block","reason":"<reason>"}` and `exit 0`.
     The decision travels in stdout JSON, matching every existing Polaris hook; no hook uses exit 2.
   - Screen the tracker snapshot through `scripts/check-patterns.sh injection` before it enters the
     reason, and withhold it on a hit. The snapshot is built from git messages and prompts, which are
     untrusted in a cloned repo. This carries over the posture `session-start` already applies to the
     same data.

2. **Wire `Stop`** in `hooks/hooks.json`. `Stop` takes no matcher, so the entry is a single handler
   group with no `matcher` key.

3. **Strip the two dead directives from `hooks/session-start`.**
   - Remove the `JOURNAL_CTX` instruction text and its `## Daily journal` block. Keep
     `polaris_journal()` — the skeleton writer is deterministic and must still run once per day.
   - Remove the whole `polaris_worktracker()` function, its call, and its `## Work tracker reconcile`
     block. Reconcile moves to `Stop` entirely. This is the one behavior change beyond relocation:
     session-start reconciled the *previous* session because it updated `.last-reconciled.local` to
     `now` before the current session did any work. Reconciling at `Stop` includes the session's own
     work, which is what the tracker was for. The `Stop` hook now owns updating that marker, and does
     so only after it has asked for the reconcile.

**Verify:** feed the hook crafted payloads directly and assert on stdout.
- `stop_hook_active: true` → empty output, exit 0.
- A journal fixture with `status: facts` → output contains `"decision":"block"` and the filename.
- Same payload twice with one `session_id` → second call produces no block.
- Nothing outstanding → empty output, exit 0.
Add each as a case in `tests/run-tests.sh`, using a temp `HOME` so the suite never reads or writes
the real memory store.

---

### Slice 3 — `userConfig` for sweep's scalars

**Files:** `.claude-plugin/plugin.json`, `commands/sweep.md`

1. Add `userConfig` to `plugin.json` with three options, each carrying the required `type`, `title`,
   and `description`:
   - `notionParentPageId` — `string`, `required: true`.
   - `timezone` — `string`, `default: "Asia/Kolkata"`.
   - `maxLookbackHours` — `number`, `default: 168`.
   None is marked `sensitive`: a Notion page id is not a credential, and `sensitive` values are
   withheld from skill content substitution, which is exactly where sweep needs them.
2. Rewrite `commands/sweep.md` step 1 resolution order to: `${user_config.KEY}` when set → the same
   key in `~/.claude/polaris-memory/sweep/config.json` → the existing not-configured stop. `sources`
   continues to come only from the JSON file. Leave the legacy project-config migration intact.

**Verify:** `claude plugin validate` passes. `python3 -c 'import json; json.load(...)'` on both
manifests. Confirm the not-configured stop still fires when neither source has a value.

---

### Slice 4 — Least privilege across the fleet

**Files:** `agents/*.md` (26), `commands/*.md` (29), `scripts/check-agents.sh`

1. **Agents.** Add `tools` to each of the 26, derived from what that agent's own prompt already does.
   No agent gains a capability. Read-only agents (`reviewer`, `verifier`, `researcher`,
   `security-architect`, `product`) get no `Edit`/`Write`. Implementers keep them.
2. **Extend `scripts/check-agents.sh`** to validate every `tools` token against the canonical tool
   names from `tools-reference.md`, and fail on an unknown one. Without this, a typo silently removes
   a tool instead of erroring, which is the failure mode that makes this slice risky.
3. **Commands.** Add `model` to each of the 29, matching the tier `rules/model-routing.md` already
   assigns. Add the missing `allowed-tools` to `commands/gate.md`.

**Verify:** `bash scripts/check-agents.sh` and `bash scripts/check-commands.sh` pass. Smoke-run two
agents across the privilege boundary — one read-only (`reviewer`) and one implementer (`backend`) —
and confirm neither reports a missing tool.

---

### Slice 5 — Docs, tests, version

**Files:** `rules/memory.md`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`, both manifests

1. `rules/memory.md` — document that the `Stop` hook drives capture and `/remember` is the manual
   override. Drop the "you maintain it as you work" framing that has not held.
2. `CLAUDE.md` — add `stop-capture` to the hooks list; note the `userConfig` options.
3. `README.md` and `CHANGELOG.md` — record the new hook, the prompted config, and the fleet pass.
4. Bump `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` to `1.9.0`. Both, per the
   gotcha in `CLAUDE.md`.

**Verify:** `bash tests/run-tests.sh` green. `bash scripts/check-patterns.sh prose` clean on every
changed markdown file.

---

## What is not proven yet

- **Memory capture quality.** Nothing here establishes that a forced `Stop` block produces one good
  entry rather than three mediocre ones. Slice 2's QA drives a real session end-to-end and inspects
  what lands in `entries/`. If it produces noise, the fix is to raise the bar stated in the reason,
  not to widen the guards.
- **Whether the block reads as disruptive.** One extra turn per working session is the cost. It needs
  a real day of use to judge, which is past this run.
- **`tools` completeness on 26 agents.** The validator catches typos, not omissions. Two smoke runs
  sample the boundary; they do not prove all 26.
