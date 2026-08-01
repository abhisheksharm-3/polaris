# Flow Enforcement, Layer 5: Routing Without Invocation — Implementation Plan

> Execute with superpowers:executing-plans. Checkbox steps. TDD for the classifier and the hook.

**Goal:** A described task routes to the right Polaris tool with no command typed, decided in shell
where the patterns are unambiguous and by a cheap model where they are not.

**Tech Stack:** Claude Code plugin: JSON data, Bash, `jq`, the Slice A checker, a `type: "prompt"`
hook on Haiku.

**Source of truth:** `docs/specs/2026-08-01-flow-enforcement.md` §Layer 5.

## Global Constraints

- Prose files pass `rules/writing.md`. No inline comments in any file this plan writes.
- Routing is non-destructive. It injects `additionalContext` naming a route; it never rewrites the
  prompt and never denies a turn.
- Fail open. Any error, missing `jq`, or unreadable config leaves the prompt untouched.
- `rules/routing.md` stays the human-readable policy. `rules/patterns.json` holds the machine form.
  When they disagree, `routing.md` is right and the data is the bug.

## What the docs settled

- `UserPromptSubmit` command hooks receive `.prompt` and can emit `additionalContext`.
- `type: "prompt"` hooks return only `{"ok": bool, "reason": string}`. They cannot emit
  `additionalContext`. On `UserPromptSubmit`, `ok:false` ends the turn and shows the reason as a
  warning line.
- Multiple hooks on one event all run, and `additionalContext` from every one is kept.

So the router must be a command hook, and the cheap model can only be used as a veto. That splits
the work: Task 2 routes, Task 3 vetoes.

---

### Task 1: Routing data and the classifier script (TDD)

**Files:** Modify `rules/patterns.json`; create `scripts/route-prompt.sh`,
`tests/fixtures/routing-cases.txt`; modify `tests/run-tests.sh`.

- [ ] **Step 1:** Add a top-level `"routing"` object to `rules/patterns.json`: an array of classes,
      each `{"class", "patterns", "route", "seeds"}`. Derive every row from the table in
      `rules/routing.md` so the two stay one policy. Classes, in match order:
      `conversation` (a question about how something works, what something is, where something
      lives), `trivial`, `fix`, `bug`, `feature`, `review`, `audit`, `qa`, `cleanup`, `research`,
      `context`. `route` is the command or agent that class hands to. `seeds` is the phase list for
      classes that open a run, and empty for the rest.
- [ ] **Step 2:** Create `tests/fixtures/routing-cases.txt`: one `<expected-class><TAB><prompt>`
      line per case. At least two per class, plus five conversation cases that must route nowhere,
      plus three deliberately ambiguous prompts expected to yield `unknown`.
- [ ] **Step 3:** Add to `tests/run-tests.sh` a loop over the fixture asserting
      `scripts/route-prompt.sh` prints the expected class for each line. Run
      `bash tests/run-tests.sh`; the new assertions FAIL, the script does not exist.
- [ ] **Step 4:** Implement `scripts/route-prompt.sh`: read the prompt on stdin, lowercase it, walk
      `.routing[]` in order, and print the first class whose patterns match. Print `unknown` when
      none match or when two classes match with equal specificity. Print `conversation` and exit
      when the conversation patterns match, before any other class is considered.
- [ ] **Step 5:** Run `bash tests/run-tests.sh`; all green. Tune the patterns against failures, not
      the fixtures. A fixture changed to make a pattern pass is the test lying.
- [ ] **Step 6:** Commit: `feat: routing classes as data and a prompt classifier`

---

### Task 2: enhance-prompt becomes the router (TDD)

**Files:** Modify `hooks/enhance-prompt`, `templates/config.default.json`; modify
`tests/run-tests.sh`.

- [ ] **Step 1:** Add to `tests/run-tests.sh`: pipe a `UserPromptSubmit` payload built with
      `jq -n --arg` holding a bug-report prompt into `hooks/enhance-prompt`, assert the output
      contains `additionalContext` naming the `bug` route. Pipe one holding a conversation prompt,
      assert no routing line is emitted. Pipe one with `routing: false` in a fixture config, assert
      silence. Run the suite; the assertions FAIL.
- [ ] **Step 2:** Rewrite `hooks/enhance-prompt` to read `.prompt` from the payload instead of
      discarding it, pass it to `scripts/route-prompt.sh`, and emit `additionalContext` naming the
      class, the route, and the seeded phases.
- [ ] **Step 3:** Gate routing on its own config key, `routing`, absent meaning on. It must work on
      a project that never ran setup, which is the point of the layer. Keep the existing
      `promptEnhance` gate over the clarity directive alone, unchanged in meaning.
- [ ] **Step 4:** On `conversation`, emit nothing. On `unknown`, emit the routing table itself and
      let the session model choose, which is the current behavior with better information.
- [ ] **Step 5:** Add `"routing": true` to `templates/config.default.json` so a fresh project sees
      the key it can turn off.
- [ ] **Step 6:** Run `bash tests/run-tests.sh`; all green. Commit:
      `feat: route every prompt to its Polaris path`

---

### Task 3: the clarity veto, on the cheap model (TDD)

**Files:** Modify `hooks/hooks.json`, `rules/routing.md`; modify `tests/run-tests.sh`.

The directive in `hooks/enhance-prompt` today asks the session model to judge whether the prompt is
clear. That was meant to be a cheap model's job. A `type: "prompt"` hook is that job, done by Haiku
before the expensive model reads anything.

- [ ] **Step 1:** Add a second `UserPromptSubmit` entry to `hooks/hooks.json` of `type: "prompt"`,
      no `model` field so it takes the configured small fast model. Prompt: return
      `{"ok": false, "reason": "..."}` only when the prompt names neither a target nor an action,
      and the reason must be the sharpened restatement, since that is the only text the user sees.
- [ ] **Step 2:** Keep the veto conservative. It ends the turn, so a false positive costs the user
      a retype. Anything that names a file, a symbol, an error, or a concrete verb passes.
- [ ] **Step 3:** Validate `jq . hooks/hooks.json`. Add a test asserting the file parses and that
      both `UserPromptSubmit` entries are present.
- [ ] **Step 4:** Document both hooks in `rules/routing.md` under a new section: what routes
      deterministically, what the veto catches, and how to turn each off.
- [ ] **Step 5:** Run `bash tests/run-tests.sh` and `bash scripts/check-patterns.sh prose
      rules/routing.md`; both green. Commit:
      `feat: veto an unactionable prompt on the cheap model`

---

### Task 4: live verification

The plugin runs from an installed cache that lags this repo, so none of the above is proven by the
suite alone.

- [ ] **Step 1:** Update the installed plugin and start a fresh session.
- [ ] **Step 2:** Type a bug description with no command. Confirm the route is announced and the
      work goes to `bug-fixer` with a reproduction first.
- [ ] **Step 3:** Type a question about how a hook works. Confirm nothing routes and no extra
      context appears.
- [ ] **Step 4:** Type a one-word prompt. Confirm the veto fires once and the reason is a usable
      restatement.
- [ ] **Step 5:** Set `routing: false` in `.polaris/config.json`. Confirm silence.
- [ ] **Step 6:** Record the results in `.polaris/runs/`, and log any misroute as a fixture case
      before fixing the pattern.

---

## Out of scope

The run ledger, the sequence gates, the Stop engine, and the six workflows. This layer routes to
the commands that exist today. Nothing about how they run changes here.
