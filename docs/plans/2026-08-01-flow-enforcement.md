# Flows as Data — Implementation Plan

> Execute with superpowers:executing-plans. Checkbox steps. TDD for every script and hook.

**Goal:** Polaris picks the flow from what the user described, records it in a ledger, and refuses
to let it run out of order.

**Tech Stack:** Claude Code plugin: JSON data, Bash, `jq`, the Slice A checker, a `type: "prompt"`
hook on the small model, and three workflow scripts.

**Source of truth:** `docs/specs/2026-08-01-flow-enforcement.md`.

## Global Constraints

- Prose files pass `rules/writing.md`. No inline comments in any file this plan writes.
- Fail open everywhere. A missing `jq`, an unreadable config, or a malformed ledger leaves the
  session untouched rather than blocking it.
- `rules/routing.md` stays the human-readable policy. `rules/flows.json` and the `routing` section
  of `rules/patterns.json` are the machine form. When they disagree, `routing.md` is right and the
  data is the bug.
- No hook blocks twice for the same phase transition. The atomic-mkdir marker in
  `hooks/stop-capture` is the pattern to copy, including its refusal to block when the marker
  cannot be created.
- Flows compose the 29 existing commands and the fleet as they are. This plan changes no command.

## What the docs settled

- `UserPromptSubmit` command hooks receive `.prompt` and can emit `additionalContext`.
- `type: "prompt"` hooks return only `{"ok", "reason"}` and cannot emit `additionalContext`. On
  `UserPromptSubmit`, `ok: false` ends the turn and shows the reason as a warning line.
- `UserPromptExpansion` receives `command_name` and `cwd` and blocks with top-level
  `{"decision": "block", "reason": "..."}`.
- `PreToolUse` matches `Task` and `Workflow`.
- A plugin ships workflows from a `workflows/` directory at its root, namespaced `/polaris:<name>`.
- Workflow subagents run in `acceptEdits` and take a fleet agent's tool restrictions only when the
  script passes `opts.agentType`.

Routing must be a command hook; the cheap model can only veto. Tasks 4 and 8 split accordingly.

---

### Task 1: the flow catalog and its validator (TDD)

**Files:** Create `rules/flows.json`, `scripts/check-flows.sh`; modify `tests/run-tests.sh`.

- [ ] **Step 1:** Write `rules/flows.json` with the 18 flows from the spec. Each flow is
      `{"phases": [{"name", "run", "evidence", "approve"}]}` where `run` is `agent:<name>`,
      `command:<name>`, or `workflow:<name>`, and `approve` is present only on phases that need a
      human before the next one starts. Derive every row from `rules/routing.md`.
- [ ] **Step 2:** Add to `tests/run-tests.sh` an assertion that `scripts/check-flows.sh` exits 0.
      Run the suite; it FAILS, the script does not exist.
- [ ] **Step 3:** Implement `scripts/check-flows.sh`: parse `flows.json`, and for every phase assert
      the `run` target resolves. `agent:<name>` must exist in `agents/`, `command:<name>` in
      `commands/`, `workflow:<name>` in `workflows/`. Print `flow:phase: unresolved <target>` and
      exit 1 on any miss.
- [ ] **Step 4:** Deliberately break one target, confirm the checker catches it, restore it.
      Workflow targets fail until Task 9, so gate that arm behind the directory existing.
- [ ] **Step 5:** Run `bash tests/run-tests.sh`; all green. Commit:
      `feat: the flow catalog and a resolver check`

---

### Task 2: the run ledger (TDD)

**Files:** Create `scripts/run-state.sh`; modify `tests/run-tests.sh`.

- [ ] **Step 1:** Add to `tests/run-tests.sh`, against a temp project dir: `seed bug demo` writes a
      ledger at `current: reproduce`; `assert fix` exits non-zero with a reason naming the phase
      that is not done; `record reproduce` with a missing artifact exits non-zero; `record` with a
      real file stores its `sha256`; a `record` whose stored hash no longer matches the file makes
      `assert` fail; `approve` then `assert` on the next phase exits 0; `clear` removes the run.
      Run the suite; every assertion FAILS.
- [ ] **Step 2:** Implement `scripts/run-state.sh` with subcommands `get`, `seed`, `record`,
      `approve`, `assert`, `clear`, writing `.polaris/runs/<slug>/state.json`.
- [ ] **Step 3:** `record` takes a phase, an artifact path, and an evidence string. It refuses when
      the artifact is missing, and stores `sha256`, `evidence`, and `at`.
- [ ] **Step 4:** `assert <phase>` reads the flow from `flows.json`, walks phases up to the named
      one, and fails naming the first that is not `done`, or is `done` but whose stored hash no
      longer matches its artifact, or that carries `approve` without an approval stamp.
- [ ] **Step 5:** Enforce one open run per project. `seed` over an existing open run exits non-zero
      naming the open slug.
- [ ] **Step 6:** Run `bash tests/run-tests.sh`; all green. Commit:
      `feat: the run ledger, with evidence per phase`

---

### Task 3: the prompt classifier (TDD)

**Files:** Modify `rules/patterns.json`; create `scripts/route-prompt.sh`,
`tests/fixtures/routing-cases.txt`; modify `tests/run-tests.sh`.

- [ ] **Step 1:** Add a top-level `"routing"` array to `rules/patterns.json`: per flow, the trigger
      patterns that identify it, in match order, with `conversation` first.
- [ ] **Step 2:** Create `tests/fixtures/routing-cases.txt`, `<expected-class><TAB><prompt>` per
      line: two cases minimum per flow, five conversation cases that must route nowhere, three
      ambiguous prompts expected to yield `unknown`.
- [ ] **Step 3:** Add a fixture loop to `tests/run-tests.sh` asserting `scripts/route-prompt.sh`
      prints the expected class per line. Run the suite; the assertions FAIL.
- [ ] **Step 4:** Implement `scripts/route-prompt.sh`: read the prompt on stdin, lowercase, walk
      `.routing[]` in order, print the first class whose patterns match. Print `conversation` and
      exit before any other class is considered. Print `unknown` when nothing matches or two
      classes tie.
- [ ] **Step 5:** Run the suite; all green. Tune patterns against failures, never fixtures. A
      fixture edited to make a pattern pass is the test lying.
- [ ] **Step 6:** Commit: `feat: classify a prompt into a flow`

---

### Task 4: enhance-prompt routes and seeds (TDD)

**Files:** Modify `hooks/enhance-prompt`, `templates/config.default.json`; modify
`tests/run-tests.sh`.

This is the task that turns routing from advice into enforcement. The announcement is text the
model may ignore; the seeded ledger is state the Task 5 gates read.

- [ ] **Step 1:** Add to `tests/run-tests.sh`, with `jq -n --arg` payloads against a temp project:
      a bug-report prompt seeds a `bug` ledger and emits `additionalContext` naming the flow and
      its phases; a conversation prompt emits nothing and seeds nothing; an `unknown` prompt emits
      the routing table and seeds nothing; a prompt arriving with a run already open emits the open
      run's current phase and does not seed a second; `routing: false` in config emits nothing.
      Run the suite; all FAIL.
- [ ] **Step 2:** Rewrite `hooks/enhance-prompt` to read `.prompt` rather than discard it, pass it
      to `route-prompt.sh`, and act on the class.
- [ ] **Step 3:** On a confident class other than `conversation`, call `run-state.sh seed` with a
      slug derived from the prompt, then emit `additionalContext` naming the flow, its phases, and
      the first phase to run. On `conversation`, emit nothing. On `unknown`, emit an instruction to
      compose a flow, which Task 7 implements; until then it emits the routing table.
- [ ] **Step 4:** Gate on a `routing` config key, absent meaning on, since it must work on a project
      that never ran setup. Leave the existing `promptEnhance` gate over the clarity path unchanged
      in meaning. Add `"routing": true` to `templates/config.default.json`.
- [ ] **Step 5:** Run the suite; all green. Commit: `feat: route a described task and open its run`

---

### Task 5: the gates and the phase engine (TDD)

**Files:** Create `hooks/guard-phase`, `hooks/advance-flow`; modify `hooks/hooks.json`,
`tests/run-tests.sh`; create `commands/pause.md`.

- [ ] **Step 1:** Add to `tests/run-tests.sh`: a `PreToolUse` payload dispatching `backend` against
      a ledger at `reproduce` is denied with a reason naming the current phase; the same against a
      ledger at `fix` is allowed; a payload with no open run is allowed. A `Stop` payload with a
      phase done and `approve: true` blocks instructing a presentation; with no approval needed it
      blocks instructing the next phase; with the flow complete it is silent; with
      `stop_hook_active` true it is silent. Run the suite; all FAIL.
- [ ] **Step 2:** Implement `hooks/guard-phase` as `PreToolUse` on `Task`: read the ledger, resolve
      the current phase's `run` target, and deny a dispatch the phase does not name via
      `permissionDecision: "deny"`.
- [ ] **Step 3:** Implement `hooks/advance-flow` as `Stop`: copy the loop-breaker and atomic-mkdir
      marker from `hooks/stop-capture` verbatim in behavior, keyed by slug and phase so it blocks
      once per transition. Never block when the marker cannot be created.
- [ ] **Step 4:** Register both in `hooks/hooks.json`. Validate with `jq .`.
- [ ] **Step 5:** Write `commands/pause.md`: clear the open run via `run-state.sh clear`, say what
      was cleared, and stop.
- [ ] **Step 6:** Run the suite; all green. Commit: `feat: refuse an out-of-phase dispatch, advance
      the flow at Stop`

---

### Task 6: live verification of the bug flow

Nothing above is proven by the suite alone; the installed plugin cache lags this repo.

- [ ] **Step 1:** Update the installed plugin, start a fresh session.
- [ ] **Step 2:** Describe a real bug with no command typed. Confirm the `bug` flow is announced,
      the ledger opens at `reproduce`, and the work starts with a reproduction.
- [ ] **Step 3:** Ask for the fix before the reproduction is recorded. Confirm `guard-phase` denies
      it and names the phase.
- [ ] **Step 4:** Let the turn end mid-flow. Confirm `advance-flow` blocks once, names the next
      phase, and does not block again for the same transition.
- [ ] **Step 5:** Run `/polaris:pause`. Confirm the run clears and the next prompt routes freshly.
- [ ] **Step 6:** Ask a question about the codebase. Confirm nothing routes, nothing seeds, and no
      extra context appears.
- [ ] **Step 7:** Record the results in `.polaris/runs/`, and log every misroute as a fixture case
      in Task 3 before touching a pattern.

---

### Task 7: the flow composer (TDD)

**Files:** Create `commands/compose.md`, `scripts/inventory.sh`; modify `hooks/enhance-prompt`,
`scripts/run-state.sh`, `rules/routing.md`; modify `tests/run-tests.sh`.

The catalog is the fast path, not the boundary. A task matching no row still gets a flow, composed
from what Polaris has. `/synthesize` is the sibling on the capability axis; this one fills a
sequence gap rather than a capability gap.

- [ ] **Step 1:** Write `scripts/inventory.sh`: print every dispatchable target as
      `agent:<name>`, `command:<name>`, `workflow:<name>`, each with its one-line description from
      the file's frontmatter. This is what the composer reads, so it can never name a target that
      does not exist.
- [ ] **Step 2:** Add to `tests/run-tests.sh`: `inventory.sh` lists all 27 agents and all commands,
      and every line it prints resolves under `scripts/check-flows.sh` rules. Run the suite; FAILS.
- [ ] **Step 3:** Implement `inventory.sh`. Run the suite; green.
- [ ] **Step 4:** Extend `run-state.sh seed` to accept a composed phase list on stdin rather than a
      catalog flow name, validating every `run` target through the same check `check-flows.sh` uses
      and rejecting the seed when one does not resolve. Add a test for a composed seed naming a
      nonexistent agent, asserting it is refused.
- [ ] **Step 5:** Write `commands/compose.md`: read the task, read `scripts/inventory.sh`, and
      return an ordered phase list in `flows.json` shape, marking the phases that need approval.
      Constrain it to the smallest sequence that completes the task, per the laziness ladder: a
      composed flow with a phase that earns nothing is the over-engineering failure on a new axis.
      Model tier per `rules/model-routing.md`.
- [ ] **Step 6:** Change the `unknown` branch of `hooks/enhance-prompt` to dispatch `compose`,
      seed the returned list, and announce it. Announce the phase list before the first phase runs,
      so a wrong composition is visible at phase zero rather than at phase four.
- [ ] **Step 7:** Add promotion: `run-state.sh` counts completed composed flows by their phase
      signature, and at three uses prints a suggestion to add the row to `flows.json`. Suggest
      only; a table row is a human's edit.
- [ ] **Step 8:** Document composition in `rules/routing.md`: when the catalog is used, when a flow
      is composed, and how to edit a composed flow before it runs. Run the suite and the prose
      check; both green. Commit: `feat: compose a flow when no named one fits`

---

### Task 8: the clarity veto on the small model

**Files:** Modify `hooks/hooks.json`, `hooks/enhance-prompt`, `rules/routing.md`;
modify `tests/run-tests.sh`.

The directive in `enhance-prompt` asks the session model to judge whether its own prompt is clear.
That judgment was meant for a cheap model.

- [ ] **Step 1:** Add a second `UserPromptSubmit` entry to `hooks/hooks.json` of `type: "prompt"`,
      with no `model` field so it takes the configured small fast model. It returns
      `{"ok": false, "reason": "..."}` only when the prompt names neither a target nor an action,
      and the reason must be the sharpened restatement, since that is the only text the user sees.
- [ ] **Step 2:** Keep it conservative. It ends the turn, so a false positive costs a retype.
      Anything naming a file, a symbol, an error, or a concrete verb passes.
- [ ] **Step 3:** Remove the now-duplicated clarity directive from `hooks/enhance-prompt`, leaving
      that hook to routing alone.
- [ ] **Step 4:** Add a test that `hooks.json` parses and both `UserPromptSubmit` entries are
      present. Document both hooks in `rules/routing.md`: what routes deterministically, what the
      veto catches, and how to turn each off.
- [ ] **Step 5:** Run `bash tests/run-tests.sh` and `bash scripts/check-patterns.sh prose
      rules/routing.md`; both green. Commit: `feat: veto an unactionable prompt on the small model`

---

### Task 9: the three workflows

**Files:** Create `workflows/verify.js`, `workflows/review.js`, `workflows/build.js`; modify
`.claude-plugin/plugin.json`, `rules/flows.json`.

Answer the `SubagentStart` question before writing the second script.

- [ ] **Step 1:** Write `workflows/verify.js`: the convergence loop shared by `bug`, `audit`, `qa`,
      and `security`. Keep running finders until two consecutive rounds surface nothing new,
      deduping against every finding seen rather than the confirmed set, with a round ceiling as a
      runaway guard. Each finding goes to three verifiers with different lenses, surviving on a
      majority.
- [ ] **Step 2:** Run it once and read the transcript: did `SubagentStart` fire, so did
      `inject-standard` reach its agents? If not, carry the standard in every workflow prompt and
      record the finding in the spec's risk section.
- [ ] **Step 3:** Every `agent()` call passes `opts.agentType` naming a fleet agent, or the fleet's
      1.9.0 tool restrictions do not apply. Set `opts.model` and `opts.effort` from
      `rules/model-routing.md`.
- [ ] **Step 4:** Write `workflows/review.js`: reviewers across the dimensions with the
      over-engineering axis mandatory, then verification through the same panel.
- [ ] **Step 5:** Write `workflows/build.js`: implement, review, QA, until clean.
- [ ] **Step 6:** Point the matching `flows.json` phases at `workflow:<name>`. Run
      `scripts/check-flows.sh`; the workflow arm now resolves. Commit:
      `feat: the three fan-out workflows`

---

### Task 10: the remaining gate and the visible state

**Files:** Create `hooks/guard-command`; modify `hooks/hooks.json`, the phase command frontmatter,
`README.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.

- [ ] **Step 1:** Implement `hooks/guard-command` as `UserPromptExpansion` matching the phase
      commands: read `cwd`, call `run-state.sh assert`, and block with top-level
      `{"decision": "block", "reason": "..."}` when the predecessor is not approved.
- [ ] **Step 2:** Add `disable-model-invocation: true` to the phase commands' frontmatter so the
      model cannot fire a phase out of order on its own.
- [ ] **Step 3:** Add a statusLine reading `polaris: <slug> · <phase> <n>/<total>` from the ledger.
- [ ] **Step 4:** Document the flow catalog in `README.md`: what a flow is, the 18 rows, and that
      adding one is a table row.
- [ ] **Step 5:** Bump the version in both `.claude-plugin/plugin.json` and
      `.claude-plugin/marketplace.json`, write the `CHANGELOG.md` entry, run
      `bash tests/run-tests.sh`, `bash scripts/check-agents.sh`, and `bash scripts/check-commands.sh`.
- [ ] **Step 6:** Commit and cut the release.

---

## Out of scope

Agent teams, checkpointing, `PostToolBatch`, the sweep family, and rewriting any of the 29
commands. Flows compose them as they are.
