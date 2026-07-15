# Slice C: Handoff and Audit Docs — Design Spec

Date: 2026-07-04. Status: design.
Parent: `docs/POLARIS_MASTER_PLAN.md` §7. Depends on Slice A (the standard and gate).

Slice C gives Polaris two things: a way to hand off work to a fresh thread without re-explaining,
and a strict prod-readiness audit that produces a written report a human can trust. Both write
into one enforced doc layout so nothing scatters.

## Problem

- Context is lost between threads. Picking up work means re-explaining what it is, what is done,
  what remains, and what was decided. The user has felt this pain directly.
- An audit is only as good as the trust it earns. A performative "looks fine" is worse than
  nothing. There is no rigorous, evidence-backed audit deliverable today.
- Polaris output (specs, plans, reports, handoffs) has no enforced home, so docs scatter.

## Goal

One doc layout, a `/handoff` generator with two variants, and a strict audit agent modeled on the
prod-readiness handoff style. Every doc passes the writing standard from Slice A.

### Success criteria

- A canonical `.polaris/` doc layout exists and is documented; the handoff generator and audit
  agent write only there, with dated, kebab-case names.
- `/handoff` produces a feature handoff or an audit handoff from real repo state (git diff, memory,
  config, recent commits), filled from a template, not a blank skeleton.
- A `prod-audit` agent runs an exhaustive, adversarial, multi-agent audit and writes a report with
  findings by severity and a blunt residual-risk statement. It reports; it does not silently fix.
- Running `/handoff` on the Polaris repo itself produces a correct, useful doc.

## The reference

`sage/PROD_READINESS_AUDIT_HANDOFF.md` is the quality bar for the audit handoff. Its structure is
adopted: a trust-framing preamble, the non-negotiable standard, read-first order, remaining work,
the adversarial audit method, skills to load, locked decisions and gotchas, working rules, and a
definition-of-done checklist that demands evidence.

## Architecture

### The `.polaris/` doc layout (enforced)

```
.polaris/
  config.json          (from Slice A)
  handoffs/            YYYY-MM-DD-<topic>-handoff.md
  audits/              YYYY-MM-DD-<topic>-audit.md
  specs/               YYYY-MM-DD-<topic>-spec.md
  plans/               YYYY-MM-DD-<topic>-plan.md
  reports/             YYYY-MM-DD-<topic>-report.md
```

Rules: one directory, dated kebab-case names, one topic per file, no stray docs elsewhere. The
generator and the audit agent create the subdirectory on demand.

### Files

```
commands/
  handoff.md           /handoff [feature|audit] [topic] -> writes .polaris/handoffs or /audits
agents/
  prod-audit.md        strict prod-readiness auditor; writes an audit report
templates/
  handoff-feature.md   feature handoff template
  handoff-audit.md     audit handoff template (sage-modeled)
rules/
  doc-organization.md  the .polaris/ layout + naming, injected so agents keep docs tidy
```

### `/handoff` command

Two variants:

- **feature** (default): captures in-progress work so a fresh thread continues without loss.
  Gathers: current branch and status, the changeset (`git diff`), recent commits, the active work
  from memory and `.polaris/config.json`, and open threads. Fills `templates/handoff-feature.md`.
  Writes `.polaris/handoffs/<date>-<topic>-handoff.md`.
- **audit**: produces an audit *handoff* (the brief that sends a fresh thread to do the audit),
  filled from `templates/handoff-audit.md`, scoped to the branch diff.

### Feature handoff template sections

What this is; current status (one blunt paragraph); what is done (with evidence); what remains
(ordered, each with the next concrete step); how to continue (read-first order); decisions locked;
gotchas; definition of done.

### Audit handoff template sections (sage-modeled)

Trust-framing preamble; the standard (non-negotiable: correct and complete, secure, performant,
clean, gate-compliant); what this work is and the exact audit surface (the diff); read-first order;
remaining work to finish first; the audit method (multi-agent, adversarial, per-subsystem, verify
every finding by trying to refute it, loop until a clean pass); skills to load; known landscape and
locked decisions; working rules; definition of done as an evidence checklist.

### `prod-audit` agent

Performs the audit the handoff describes. Method: detect the surface (branch diff), dispatch
independent per-subsystem reviewers (correctness, security, performance, clean-code), verify every
finding adversarially, loop until a pass finds nothing new. It reads the Slice A standard and runs
the quality gate as one of its lenses. Output: a report in `.polaris/audits/` with findings by
severity (Critical/High/Medium), each with `file:line` and evidence, plus a residual-risk
statement that tells the whole truth. It reports; fixing is handed to `code-cleanup` or
`audit-refactor`. Follows the agent contract (§6.0), runs on the Opus tier (adversarial work).

## Testing and validation

- Templates and the command are content; validate by generating a feature handoff for the Polaris
  repo and confirming it captures real state (branch, changeset, remaining work) correctly.
- Run every generated doc through `check-patterns.sh prose` to confirm it passes the writing bar.
- The `prod-audit` agent is validated by pointing it at a small real diff and reviewing the report
  for correct findings and an honest residual-risk statement.

## Out of scope

- Auto-fixing during audit (handed to the fixer agents).
- The full agent fleet (Slice B), the orchestration cycle (Slice D).
