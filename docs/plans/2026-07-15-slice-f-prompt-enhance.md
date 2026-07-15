# Slice F: Prompt Enhancing Implementation Plan

> Execute with superpowers:executing-plans. Checkbox steps. TDD for the hook.

**Goal:** A gated judge-then-enhance UserPromptSubmit hook and an `/enhance` command.

## Global Constraints

- Off by default (`promptEnhance: false`); the hook injects only when the project config enables it.
- The hook never rewrites the prompt; it injects `additionalContext`.
- Prose passes `rules/writing.md`. Source: `docs/specs/2026-07-15-slice-f-prompt-enhance.md`.

---

### Task 1: The enhance-prompt hook (TDD)

**Files:** Modify `templates/config.default.json`, `tests/run-tests.sh`; create `hooks/enhance-prompt`; modify `hooks/hooks.json`.

- [ ] **Step 1:** Add `"promptEnhance": false` to `templates/config.default.json`.
- [ ] **Step 2:** Add to `tests/run-tests.sh`: make a temp project dir with `.polaris/config.json` where `promptEnhance` is true; run `CLAUDE_PROJECT_DIR=<tmp> hooks/enhance-prompt` on a UserPromptSubmit payload and assert `additionalContext` present; repeat with `promptEnhance` false and assert silence.
- [ ] **Step 3:** Run the suite; new assertions FAIL (hook missing).
- [ ] **Step 4:** Implement `hooks/enhance-prompt`: read stdin; read `${CLAUDE_PROJECT_DIR:-$PWD}/.polaris/config.json`; if `.promptEnhance != true`, exit 0; else emit `{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:"<judge-then-enhance directive>"}}` via `jq -cn`. `chmod +x`.
- [ ] **Step 5:** Register in `hooks/hooks.json` a `UserPromptSubmit` entry calling `run-hook.cmd enhance-prompt`.
- [ ] **Step 6:** Run the suite (green); `jq . hooks/hooks.json`.
- [ ] **Step 7:** Commit: `git add hooks/ tests/run-tests.sh templates/config.default.json && git commit -m "feat: gated judge-then-enhance prompt hook"`

---

### Task 2: The /enhance command

**Files:** Create `commands/enhance.md`.

- [ ] **Step 1:** Author `commands/enhance.md`: judge the prompt in `$ARGUMENTS`; if vague, enrich with config, memory, repo, and connector context, wiring `prompt-optimizer`; return the enriched prompt (or run it if asked).
- [ ] **Step 2:** Verify prose (exit 0).
- [ ] **Step 3:** Commit: `git add commands/enhance.md && git commit -m "feat: /enhance command"`

---

### Task 3: Validate, version, README

**Files:** Modify `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`.

- [ ] **Step 1:** Full suite green. Bump both manifests to `0.9.0`. Add a README row for prompt enhancing.
- [ ] **Step 2:** `bash scripts/check-patterns.sh prose README.md commands/enhance.md`; `jq . .claude-plugin/*.json`.
- [ ] **Step 3:** Commit: `git add -A && git commit -m "chore: validate slice F, bump to 0.9.0, README"`
