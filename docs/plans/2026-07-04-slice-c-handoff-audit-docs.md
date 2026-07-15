# Slice C: Handoff and Audit Docs Implementation Plan

> **For agentic workers:** Execute task-by-task with superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** A `/handoff` generator (feature + audit variants), a strict `prod-audit` agent, and an enforced `.polaris/` doc layout, all writing docs that pass the Slice A writing standard.

**Architecture:** Templates in `templates/`, a command and an agent that fill them from real repo state, and a `rules/doc-organization.md` injected so every agent keeps docs tidy. The audit agent reports; fixing is handed to the Slice A agents.

**Tech Stack:** Claude Code plugin (markdown command, agent, templates, rule), the Slice A checker for validation.

## Global Constraints

- Every generated doc and every file here passes `rules/writing.md` (verify with `scripts/check-patterns.sh prose`).
- Plugin agents use only supported frontmatter (`model`, `effort`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation`); `prod-audit` sets `model: opus` (adversarial work).
- Docs live only under `.polaris/`, dated kebab-case, one topic per file.
- Source of truth: `docs/specs/2026-07-04-slice-c-handoff-audit-docs.md`; audit quality bar: `sage/PROD_READINESS_AUDIT_HANDOFF.md`.

---

### Task 1: The doc-organization rule

**Files:** Create `rules/doc-organization.md`; modify `hooks/session-start`.

- [ ] **Step 1:** Author `rules/doc-organization.md`: the `.polaris/` layout (handoffs, audits, specs, plans, reports), the naming rule (`YYYY-MM-DD-<topic>-<kind>.md`), one-topic-per-file, no stray docs. Short and declarative.
- [ ] **Step 2:** In `hooks/session-start`, after the writing.md block, append `rules/doc-organization.md` to `combined_context` the same way (guarded `if [ -f ]`).
- [ ] **Step 3:** Verify: `bash -n hooks/session-start && bash scripts/check-patterns.sh prose rules/doc-organization.md; echo $?` expects syntax ok and exit 0 (rules/ is skipped).
- [ ] **Step 4:** Commit: `git add rules/doc-organization.md hooks/session-start && git commit -m "feat: enforced .polaris doc layout, injected at session start"`

---

### Task 2: Handoff templates

**Files:** Create `templates/handoff-feature.md`, `templates/handoff-audit.md`.

- [ ] **Step 1:** Author `templates/handoff-feature.md` with placeholder tokens (`{{...}}`) and these sections: What this is; Current status (one blunt paragraph); What is done (with evidence); What remains (ordered, each with the next concrete step); How to continue (read-first order); Decisions locked; Gotchas; Definition of done.
- [ ] **Step 2:** Author `templates/handoff-audit.md` modeled on the sage reference: trust-framing preamble; §0 the standard (correct and complete, secure, performant, clean, gate-compliant); §1 what this work is + the exact audit surface (the diff); §2 read-first order; §3 remaining work to finish first; §4 the audit method (multi-agent, adversarial, per-subsystem, refute every finding, loop until clean); §5 skills to load; §6 known landscape and locked decisions; §7 working rules; §8 definition of done as an evidence checklist.
- [ ] **Step 3:** Verify both pass the writing standard: `bash scripts/check-patterns.sh prose templates/handoff-feature.md templates/handoff-audit.md; echo $?` expects exit 0.
- [ ] **Step 4:** Commit: `git add templates/handoff-*.md && git commit -m "feat: feature and audit handoff templates"`

---

### Task 3: The /handoff command

**Files:** Create `commands/handoff.md`.

- [ ] **Step 1:** Author `commands/handoff.md`. Frontmatter: `description`, `argument-hint: "[feature|audit] [topic]"`, `allowed-tools: Read, Write, Bash, Grep, Glob`. Body: parse `$ARGUMENTS` for variant (default `feature`) and topic. Gather real state: `git branch --show-current`, `git status -s`, `git diff --stat`, `git log --oneline -10`, `.polaris/config.json`, and relevant memory. Fill the matching template. Write to `.polaris/handoffs/<date>-<topic>-handoff.md` (feature) or `.polaris/audits/<date>-<topic>-audit-handoff.md` (audit). Never write a blank skeleton; every section filled from real state or marked "none".
- [ ] **Step 2:** Verify frontmatter and prose: `head -5 commands/handoff.md && bash scripts/check-patterns.sh prose commands/handoff.md; echo $?` expects exit 0.
- [ ] **Step 3:** Commit: `git add commands/handoff.md && git commit -m "feat: /handoff command (feature + audit variants)"`

---

### Task 4: The prod-audit agent

**Files:** Create `agents/prod-audit.md`.

- [ ] **Step 1:** Author `agents/prod-audit.md`. Frontmatter: `name: prod-audit`, `model: opus`, a `description` with triggers ("prod readiness audit", "is this safe to ship", "audit before release"), `skills` listing the quality gate and relevant review skills. Body: the agent contract (§6.0); the non-negotiable standard (from the audit template §0); the adversarial multi-agent method (independent per-subsystem reviewers, refute every finding, loop until clean); run the Slice A gate as one lens; write a report to `.polaris/audits/<date>-<topic>-audit.md` with findings by severity + `file:line` + evidence, and a blunt residual-risk statement. It reports only; hand fixes to `code-cleanup` / `audit-refactor`.
- [ ] **Step 2:** Verify: `head -6 agents/prod-audit.md && bash scripts/check-patterns.sh prose agents/prod-audit.md; echo $?` expects the frontmatter and exit 0.
- [ ] **Step 3:** Commit: `git add agents/prod-audit.md && git commit -m "feat: strict prod-audit agent (report-only, sage-modeled)"`

---

### Task 5: Validate, version, README

**Files:** Modify `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`.

- [ ] **Step 1:** Generate a real feature handoff for this repo by following `commands/handoff.md` manually: gather git state and write `.polaris/handoffs/<date>-slice-c-handoff.md`. Confirm it captures the real branch, changeset, and remaining work.
- [ ] **Step 2:** Run it through the standard: `bash scripts/check-patterns.sh prose .polaris/handoffs/*.md; echo $?` expects exit 0.
- [ ] **Step 3:** Bump version to `0.4.0` in both manifests. Add a Subsystem C row set to the README component table and skill-routing table (`/handoff`, `prod-audit`).
- [ ] **Step 4:** Verify README: `bash scripts/check-patterns.sh prose README.md; echo $?` expects exit 0.
- [ ] **Step 5:** Commit: `git add -A && git commit -m "chore: validate slice C on this repo, bump to 0.4.0, README"`

---

## Notes

- Work on `main` (project rule), commit per task.
- The `.polaris/` dir is created in the target project; for this repo, the generated handoff is a real artifact and can be committed as the validation evidence.
