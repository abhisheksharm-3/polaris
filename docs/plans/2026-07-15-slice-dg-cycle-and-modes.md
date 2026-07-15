# Slice D+G: Cycle and Modes Implementation Plan

> Execute with superpowers:executing-plans. Checkbox steps.

**Goal:** A `/flow` orchestrator and three standalone-mode commands, all referencing the real fleet, gated and capped, passing the writing standard.

**Tech Stack:** Claude Code plugin commands; validated with the Slice A checker and a dangling-reference check.

## Global Constraints

- Commands reference only agents that exist in `agents/`.
- Prose passes `rules/writing.md`.
- Approval gates (spec, design, plan) are explicit stops; verify loops cap at 3 rounds then escalate.
- Source of truth: `docs/specs/2026-07-15-slice-dg-cycle-and-modes.md`.

---

### Task 1: The /flow orchestrator

**Files:** Create `commands/flow.md`.

- [ ] **Step 1:** Author `commands/flow.md`. Frontmatter: `description`, `argument-hint: "<task or PRD>"`, `allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob`. Body: the phase table from the spec, each phase naming its fleet agent(s) and primitive; the approval gates at spec/design/plan as explicit stops; the loop caps (3 rounds then escalate); path-scaling by task size; artifacts to `.polaris/`; a final report with the PR link.
- [ ] **Step 2:** Verify frontmatter and prose: `head -5 commands/flow.md && bash scripts/check-patterns.sh prose commands/flow.md; echo $?` (exit 0).
- [ ] **Step 3:** Commit: `git add commands/flow.md && git commit -m "feat: /flow orchestration cycle command"`

---

### Task 2: Standalone mode commands

**Files:** Create `commands/research.md`, `commands/onboard.md`, `commands/explain.md`.

- [ ] **Step 1:** Author all three per the spec, each invoking its fleet agent(s), worktree-isolated when writing, artifacts to `.polaris/reports/`.
- [ ] **Step 2:** Verify prose over the three (exit 0).
- [ ] **Step 3:** Commit: `git add commands/ && git commit -m "feat: research, onboard, explain standalone modes"`

---

### Task 3: Dangling-reference check

**Files:** Create `scripts/check-commands.sh`; modify `tests/run-tests.sh`.

- [ ] **Step 1:** Write `scripts/check-commands.sh`: for each `agents/<name>` referenced in `commands/flow.md` (grep for backticked or bare agent names against the actual `agents/*.md` basenames), assert the agent file exists; exit non-zero on any missing.
- [ ] **Step 2:** Add `expect_exit 0 bash "${DIR}/../scripts/check-commands.sh"` to `tests/run-tests.sh`.
- [ ] **Step 3:** Run `bash scripts/check-commands.sh` and the full suite; fix any dangling name in `flow.md`.
- [ ] **Step 4:** Commit: `git add scripts/check-commands.sh tests/run-tests.sh && git commit -m "feat: command agent-reference check"`

---

### Task 4: Validate, version, README

**Files:** Modify `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`.

- [ ] **Step 1:** Full suite green; `bash scripts/check-patterns.sh prose commands/*.md` exit 0.
- [ ] **Step 2:** Bump both manifests to `0.7.0`. Add README rows for `/flow` and the standalone modes.
- [ ] **Step 3:** `bash scripts/check-patterns.sh prose README.md`; `jq . .claude-plugin/*.json`.
- [ ] **Step 4:** Commit: `git add -A && git commit -m "chore: validate slice D+G, bump to 0.7.0, README"`
