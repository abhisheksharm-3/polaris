# Slice B: Agent Fleet Implementation Plan

> Execute with superpowers:executing-plans. Each task creates a domain group of agents, all following the contract in the spec, then verifies and commits.

**Goal:** Author the full agent roster from `docs/specs/2026-07-15-slice-b-agent-fleet.md`, each following the agent contract, with the model tier from the spec table.

**Tech Stack:** Claude Code plugin agents (`agents/*.md`), validated with the Slice A checker and a small frontmatter script.

## Global Constraints

- Only allowed plugin-agent frontmatter fields (`name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation`).
- Every agent prose passes `rules/writing.md`.
- Model tiers exactly as the spec table.
- Each agent body has: `## Contract`, `## Responsibilities`, `## Output`.
- Source of truth: the spec's roster table.

---

### Task 1: Validation script

**Files:** Create `scripts/check-agents.sh`; modify `tests/run-tests.sh`.

- [ ] **Step 1:** Write `scripts/check-agents.sh`: for each `agents/*.md`, assert frontmatter has `name`, `description`, `model` in {opus,sonnet}, and (for new fleet agents) `skills`; assert no forbidden field (`hooks:`, `mcpServers:`, `permissionMode:`); print `ok`/`FAIL` per file; exit non-zero on any FAIL.
- [ ] **Step 2:** Add to `tests/run-tests.sh`: `expect_exit 0 bash "${DIR}/../scripts/check-agents.sh"`.
- [ ] **Step 3:** Run `bash scripts/check-agents.sh` against the current four agents; expect all ok (they have name/description/model; existing ones may lack `skills` which is allowed for pre-fleet agents, so the script only requires `skills` when a marker is absent, or just warns). Adjust so current agents pass.
- [ ] **Step 4:** Commit: `git add scripts/check-agents.sh tests/run-tests.sh && git commit -m "feat: agent frontmatter validation script"`

---

### Task 2: Discovery and product agents

**Files:** Create `agents/product.md`, `agents/researcher.md`.

- [ ] **Step 1:** Create both per the contract and their spec rows (both `opus`).
- [ ] **Step 2:** Verify: `bash scripts/check-patterns.sh prose agents/product.md agents/researcher.md && bash scripts/check-agents.sh`.
- [ ] **Step 3:** Commit: `git add agents/ && git commit -m "feat: product and researcher agents"`

---

### Task 3: Architecture and design agents

**Files:** Create `agents/architect.md`, `agents/api-designer.md`, `agents/data-modeler.md`, `agents/security-architect.md`, `agents/ux.md`, `agents/ui.md`.

- [ ] **Step 1:** Create all six per the contract and spec rows (architect/api-designer/data-modeler/security-architect `opus`; ux/ui `sonnet`).
- [ ] **Step 2:** Verify prose + frontmatter over the six.
- [ ] **Step 3:** Commit: `git add agents/ && git commit -m "feat: architecture and design agents"`

---

### Task 4: Implementation agents

**Files:** Create `agents/frontend-logic.md`, `agents/backend.md`, `agents/integrations.md`, `agents/infra.md`, `agents/data-engineer.md`.

- [ ] **Step 1:** Create all five (`sonnet`).
- [ ] **Step 2:** Verify prose + frontmatter.
- [ ] **Step 3:** Commit: `git add agents/ && git commit -m "feat: implementation agents"`

---

### Task 5: Review and QA agents

**Files:** Create `agents/reviewer.md`, `agents/verifier.md`, `agents/tester.md`, `agents/e2e.md`, `agents/perf.md`, `agents/bug-fixer.md`.

- [ ] **Step 1:** Create all six (reviewer/verifier/tester `opus`; e2e/perf/bug-fixer `sonnet`).
- [ ] **Step 2:** Verify prose + frontmatter.
- [ ] **Step 3:** Commit: `git add agents/ && git commit -m "feat: review and QA agents"`

---

### Task 6: Docs, ship, and ops agents

**Files:** Create `agents/tech-writer.md`, `agents/shipper.md`, `agents/devops.md`, `agents/sre.md`.

- [ ] **Step 1:** Create all four (`sonnet`).
- [ ] **Step 2:** Verify prose + frontmatter.
- [ ] **Step 3:** Commit: `git add agents/ && git commit -m "feat: docs, ship, and ops agents"`

---

### Task 7: Validate, version, README

**Files:** Modify `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`.

- [ ] **Step 1:** Run `bash scripts/check-agents.sh` (all ok) and `bash tests/run-tests.sh` (green). Count: `ls agents/*.md | wc -l` should be 27.
- [ ] **Step 2:** Run every agent through the writing standard: `bash scripts/check-patterns.sh prose agents/*.md; echo $?` (exit 0).
- [ ] **Step 3:** Bump both manifests to `0.6.0`. Add a README note that Polaris ships a full role-based agent fleet.
- [ ] **Step 4:** `bash scripts/check-patterns.sh prose README.md`; `jq . .claude-plugin/*.json`.
- [ ] **Step 5:** Commit: `git add -A && git commit -m "chore: validate fleet, bump to 0.6.0, README"`
