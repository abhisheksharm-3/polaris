# Work-Tracker MVP Implementation Plan

> Execute with superpowers:executing-plans. Checkbox steps.

**Goal:** A file-based work tracker: `.polaris/work/streams.md`, surfaced at session start, updated by `/track`.

**Tech Stack:** Claude Code plugin: a template, a command, a session-start change. Validated with the Slice A checker.

## Global Constraints

- Prose passes `rules/writing.md`.
- Surfacing is deterministic (hook reads the file); updating is model-driven (`/track`).
- Source of truth: `docs/specs/2026-07-15-slice-worktracker-mvp.md`.

---

### Task 1: The work-streams template

**Files:** Create `templates/work-streams.md`.

- [ ] **Step 1:** Author `templates/work-streams.md`: a header explaining the file, then the stream structure (id/title, domain, status, state, next, files, touched) with one filled example and a `## Done` archive section.
- [ ] **Step 2:** Verify: `bash scripts/check-patterns.sh prose templates/work-streams.md; echo $?` (exit 0).
- [ ] **Step 3:** Commit: `git add templates/work-streams.md && git commit -m "feat: work-streams template"`

---

### Task 2: The /track command

**Files:** Create `commands/track.md`.

- [ ] **Step 1:** Author `commands/track.md`. Frontmatter: `description`, `allowed-tools: Read, Write, Edit, Bash, Grep, Glob`. Body: read `.polaris/work/streams.md` (create from `${CLAUDE_PLUGIN_ROOT}/templates/work-streams.md` if absent), review the current session's work, reconcile the streams (add new, update state and next, close done, flag stale), keep it lean (archive done), write back. Passes the writing standard.
- [ ] **Step 2:** Verify: `head -4 commands/track.md && bash scripts/check-patterns.sh prose commands/track.md; echo $?` (exit 0).
- [ ] **Step 3:** Commit: `git add commands/track.md && git commit -m "feat: /track command updates work streams"`

---

### Task 3: Session-start surfacing

**Files:** Modify `hooks/session-start`.

- [ ] **Step 1:** In `hooks/session-start`, after the rule-injection blocks, add: if `${PROJECT_DIR}/.polaris/work/streams.md` exists, read it and append its content to `combined_context` under a header like "## Open work (from the Polaris tracker)". (Surfacing the whole file is fine for the MVP; `/track` keeps done streams in an archive section so the active ones lead.)
- [ ] **Step 2:** Verify `bash -n hooks/session-start`. Create a sample `.polaris/work/streams.md`, run the detection block logic in isolation (or grep the script) to confirm it would include the file. Remove the sample if it was only for the test (or keep a real one).
- [ ] **Step 3:** Commit: `git add hooks/session-start && git commit -m "feat: surface open work streams at session start"`

---

### Task 4: Validate, version, README, dogfood

**Files:** Modify `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`; create `.polaris/work/streams.md`.

- [ ] **Step 1:** Dogfood: create a real `.polaris/work/streams.md` for the Polaris project capturing the current open threads (the remaining milestones), from the template. Run it through the checker.
- [ ] **Step 2:** Full suite green. Bump both manifests to `0.8.0`. Add a README row for the work tracker (`/track` + session-start surfacing).
- [ ] **Step 3:** `bash scripts/check-patterns.sh prose README.md .polaris/work/streams.md`; `jq . .claude-plugin/*.json`.
- [ ] **Step 4:** Commit: `git add -A && git commit -m "chore: work-tracker validation and dogfood, bump to 0.8.0, README"`
