# Slice H: Dynamic Agent Synthesis Implementation Plan

> Execute with superpowers:executing-plans. Checkbox steps.

**Goal:** A `/synthesize` command that composes an ephemeral agent from the skill registries for a task no fleet agent covers.

## Global Constraints

- Prefer marketplace plugins and security-graded skills; never auto-install ungraded/low-grade without approval.
- The synthesized agent follows the agent contract and runs under the gate + injection guardrail.
- Prose passes `rules/writing.md`. Source: `docs/specs/2026-07-15-slice-h-dynamic-synthesis.md`.

---

### Task 1: The /synthesize command

**Files:** Create `commands/synthesize.md`.

- [ ] **Step 1:** Author `commands/synthesize.md`. Frontmatter: `description`, `argument-hint: "<task with no fitting fleet agent>"`, `allowed-tools: Task, Read, Write, Bash, Grep, Glob, WebFetch, WebSearch`. Body: the six steps from the spec (classify + check fleet first; search registries; filter by security grade; compose via skill-creator following the contract; run under gate + guardrails; persist only if reused), with the safety rules explicit.
- [ ] **Step 2:** Verify: `head -5 commands/synthesize.md && bash scripts/check-patterns.sh prose commands/synthesize.md; echo $?` (exit 0).
- [ ] **Step 3:** Commit: `git add commands/synthesize.md && git commit -m "feat: /synthesize dynamic agent synthesis command"`

---

### Task 2: Validate, version, README

**Files:** Modify `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`.

- [ ] **Step 1:** Full suite green. Bump both manifests to `0.11.0`. Add a README row for `/synthesize`.
- [ ] **Step 2:** `bash scripts/check-patterns.sh prose README.md commands/synthesize.md`; `jq . .claude-plugin/*.json`.
- [ ] **Step 3:** Commit: `git add -A && git commit -m "chore: validate slice H, bump to 0.11.0, README"`
