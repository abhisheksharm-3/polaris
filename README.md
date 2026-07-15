# Polaris

An all-in-one project operating system for Claude Code. Polaris runs the whole software lifecycle,
from a rough idea through research, design, build, review, QA, docs, ship, and operate, and the work
around it: product, marketing, and bug fixing. It holds one quality bar across every step. The code
it produces is simple, secure, self-explanatory, and low in complexity, and every line of prose it
writes, including commit messages and PR bodies, reads like a careful human wrote it.

Polaris lives by its own rules. The standard it enforces on your code, it enforces on itself.

## The idea

An AI agent left alone drifts two ways: it over-builds (fifty lines where one would do), and it
writes text full of the tells that mark it as machine-generated. Polaris fixes both with one
standard and the machinery to enforce it.

- **One canonical standard.** Simplicity first, root-cause fixes over symptom patches, security at
  the boundary, and an anti-slop writing rule for all prose. It is split into a language-agnostic
  core, per-stack overlays, and a machine-readable pattern file.
- **A gate that enforces it.** A callable check runs a fast deterministic pass plus a judgment pass
  and reports pass or fail with `file:line` findings. Agents call it before they declare work done.
- **Hooks with teeth.** A commit and PR guard blocks banned words and AI attribution before they
  land. A tool-result guard flags prompt-injection in fetched and MCP content. Session start injects
  the standard and surfaces your open work.
- **The least code that works.** The ponytail companion adds a laziness ladder (reuse and stdlib
  before a new dependency, a one-liner before a class), applied by every code writer.

## Install

From the marketplace:

```
/plugin marketplace add abhisheksharm-3/polaris
/plugin install polaris
```

Local development:

```
claude --plugin-dir ./polaris
```

Companions install with Polaris: `superpowers` and `frontend-design` as native plugin dependencies,
and the rest (karpathy, ponytail, the daymade skills, and the Mindrally stack-skill library) synced
on first run. See `companions.json` for the full manifest.

## Setup

Run `/init` (or `/polaris:init`) at a project root. It interviews you on how the standard should
apply here (dead code, backward compatibility, architecture, naming, PR conventions, or a one-step
auto mode), writes `.polaris/config.json`, installs companions, and sets up `CLAUDE.md`. The gate,
the hooks, and every agent read that config, so the same engine enforces a different profile per
project.

## The command surface

| Command | What it does |
|---|---|
| `/flow <task>` | The full build cycle: idea to a reviewed, tested, shipped PR, with human gates at spec, design, and plan, and capped verify loops |
| `/debug <symptom>` | The bug lifecycle: interview, ground in the code and stack, reproduce, find root cause, fix the class, verify, add a regression test, write an RCA |
| `/incident <alert>` | Production incident to postmortem: triage, stabilize, root-cause, fix, blameless writeup |
| `/gate [--fix] [--scope]` | Run the quality gate on the current changeset |
| `/audit` | Whole-codebase four-category audit (security, performance, architecture, structure) |
| `/harden` | Security hardening pass: threat-model, find, verify, fix |
| `/modernize` | Upgrade dependencies or a framework safely via the migration guide |
| `/review-pr <pr>` | Review an existing PR across dimensions, verified, with an over-engineering check |
| `/triage` | Classify a batch of bugs or issues by severity, area, and next step |
| `/docs-drift` | Find docs that no longer match the code and fix them |
| `/release` | Cut a release: changelog, version bump, notes, tag |
| `/spike <question>` | A timeboxed throwaway prototype to answer a feasibility question |
| `/handoff [feature\|audit]` | Generate a handoff doc from real repo state, into `.polaris/` |
| `/track` | Reconcile this session into the cross-session work tracker |
| `/catchup` | Morning briefing across memory, the work tracker, and connectors |
| `/research`, `/onboard`, `/explain` | Standalone modes: what to build next, onboard a developer, explain how code works |
| `/enhance <prompt>` | Judge a prompt and, only if vague, enrich it with project context |
| `/synthesize <task>` | Compose an ephemeral agent from the skill registries when no fleet agent fits |
| `/remember`, `/recall` | Write to and read from global memory |
| `/init` | Setup interview, companions, and CLAUDE.md |

## Using Polaris

Polaris is organized around jobs, not tools. Each job below names the situation you are in, the one
command to run, and how to get the best result from it. Run `/init` once per project first so every
command reads your profile.

Every command scales to the input. A one-line fix runs a short path; a real feature runs the whole
cycle. Give each command real context, not a title, and you get a better result.

### Ship an idea or a feature

**Use `/flow <idea>`** when you have something to build, from a one-line change to a full product
feature. It runs the whole cycle: intake, spec, design, plan, parallel implementation, review, QA,
docs, and a shipped PR, stopping for your approval at the spec, the design, and the plan.

Use it well:

- Give it the problem, not the solution. "Users lose their draft when the session expires" beats
  "add localStorage to the editor". Polaris interviews you to close the gaps, so a rich prompt or a
  pasted PRD saves a round of questions.
- Treat the three gates as real. Read the spec, the design, and the plan when it stops. A correction
  at the spec gate costs one sentence; the same correction after implementation costs a rebuild.
- Let it fan out. Independent parts run in parallel worktrees. Do not narrow the task to one file if
  it is really several.
- Expect evidence. It reproduces, tests, and shows output before it claims done. If a claim looks
  unproven, ask for the command and the result.

For a throwaway proof of concept rather than a shipped feature, use `/spike <question>` instead. It
answers one feasibility question with the smallest prototype, then discards or graduates it to
`/flow`.

### Fix a bug

**Use `/debug <symptom>`** for any bug where the cause is not obvious. It interviews you, grounds
itself in the code, the stack docs, and the database schema, reproduces the failure, finds the root
cause, names the class of bug, fixes the class rather than the one instance, verifies, and adds a
regression test.

Use it well:

- Describe the symptom and how to trigger it, not your guess at the cause. "Totals are wrong for
  refunded orders" is enough; Polaris finds why.
- Give it a reproduction if you have one: the input, the steps, the expected versus actual result.
  A real repro is the fastest path to a real fix.
- Point it at the surface area if you know it (a file, an endpoint, a screen). It grounds faster.
- It fixes the class, so expect it to find sibling bugs. That is the point, not scope creep.

For a live production issue where the priority is to stop the bleeding, use `/incident <alert>`
instead. It stabilizes first, then diagnoses, then writes a blameless postmortem.

### Check work before it ships

**Use `/gate`** on the current changeset before you commit or open a PR. It runs a fast
deterministic pass plus a judgment pass and reports pass or fail with `file:line` findings. Add
`--fix` to correct what is safely correctable, and `--scope` to limit it.

**Use `/review-pr <pr>`** to review an existing pull request across correctness, security,
performance, and maintainability, with each finding verified and an over-engineering check.

Use them well:

- Run `/gate` yourself before you push; it is the same check the fleet runs before it declares done.
- For `/review-pr`, pass the PR number or URL. Read the over-engineering findings closely: they
  catch the fifty lines where one would do.

### Understand or clean up a codebase

**Use `/onboard`** when you are new to a repository. It maps the architecture, the conventions, and
the places that will bite you, and gives you a path in.

**Use `/explain <path or symbol>`** to understand how a specific piece works, grounded in the actual
code.

**Use `/audit`** for a whole-codebase review across security, performance, architecture, and
directory structure, with severity ratings and a fix plan before any change.

Use them well:

- Start with `/onboard` for the whole system, then `/explain` for the parts you will touch.
- Treat `/audit` as read-first. It reports and plans before it changes anything, so review the plan
  and pick what to fix.
- After `/audit`, chain the fixers: `/harden` for the security findings, `/modernize` for the
  dependency and framework debt.

### Harden, upgrade, and keep docs honest

**Use `/harden`** for a focused security pass: threat-model, find, verify, fix.

**Use `/modernize`** to upgrade a dependency or a framework safely, following the migration guide
rather than guessing.

**Use `/docs-drift`** to find documentation that no longer matches the code and fix it to match what
actually ships.

Use them well:

- Run `/modernize` on one upgrade at a time so each change is reviewable and revertible.
- Run `/docs-drift` after a feature lands and before a release, so the docs describe the shipped
  code, not the intended code.

### Plan, decide, and triage

**Use `/research <question>`** to decide what to build next or to gather prior art and options before
committing.

**Use `/triage`** to classify a batch of bugs or issues by severity, area, and next step, so a
backlog becomes a plan.

Use them well:

- Give `/research` the decision you are trying to make, not just a topic. "Should we build our own
  auth or use a provider, given our compliance needs" gets a usable answer.
- Feed `/triage` the raw list. It groups, ranks, and tells you what to do first.

### Release

**Use `/release`** to cut a release: it assembles the changelog, bumps the version, writes the notes,
and tags. **Use `/handoff [feature|audit]`** to generate a handoff document from real repository
state when you are passing work to someone else.

Use them well:

- Run `/docs-drift` and `/gate` before `/release` so the release is clean.
- Pick the `/handoff` variant that fits: `feature` to hand off in-progress work, `audit` for a
  production-readiness assessment.

### Stay oriented across sessions

**Use `/catchup`** at the start of a session for a briefing across your memory, the work tracker, and
connectors. **Use `/track`** to fold the current session into the cross-session work tracker so no
thread is lost. **Use `/remember`** and **`/recall`** to write and read durable facts in global
memory.

Use them well:

- Run `/catchup` first thing. It tells you where every parallel thread stood when you left it.
- Run `/track` when you switch threads or end a session, so the tracker stays current on its own.
- Use `/remember` for decisions and constraints that outlive one session, not for things the code
  already records.

### Get more from any prompt

**Use `/enhance <prompt>`** to have Polaris judge whether a prompt is too vague and, only if it is,
enrich it with project context before acting. **Use `/synthesize <task>`** when no fleet agent fits
the task; it composes an ephemeral agent from the skill registries, trust-filtered and
injection-screened.

## The agent fleet

A specialized agent for every role, each following one contract (load the config and the standard,
resolve the stack skills and fresh docs, run the gate before done), wiring the right host skills, and
carrying a model tier.

- **Product and research:** product, researcher
- **Architecture and design:** architect, api-designer, data-modeler, security-architect, ux, ui
- **Implementation:** frontend-logic, backend, integrations, infra, data-engineer, feature-builder
- **Review and QA:** reviewer, verifier, tester, e2e, perf, bug-fixer
- **Docs, ship, and ops:** tech-writer, shipper, devops, sre
- **Quality and audit:** code-cleanup, audit-refactor, prod-audit

## The standard and its enforcement

`rules/core.md` holds the language-agnostic engineering standard, the docs protocol (fetch
`llms.txt` then version docs before writing), the skill-resolution order, and the ponytail ladder.
`rules/writing.md` is the anti-slop writing standard for all prose. `rules/stacks/*` add per-stack
opinions, mapped by `rules/stack-map.json`. `rules/patterns.json` is the machine-readable data that
drives the deterministic checker and the hooks. `rules/routing.md` classifies each task to the
agent, command, ponytail intensity, and model tier to use.

The gate lives in `skills/quality-gate/`. The hooks are `guard-commit-pr` (blocks bad commit and PR
text), `guard-edit` (surfaces slop on edit, opt-in), `guard-input` (flags injection in tool
results), `enhance-prompt` (gated), and `session-start` (injects the standard, surfaces work and
memory, installs companions).

## Memory and the work tracker

The work tracker keeps your parallel threads in `.polaris/work/streams.md`, surfaced every session
so nothing is lost, updated by `/track`. Global memory lives in `~/.claude/polaris-memory/`, written
by `/remember` and read by `/recall`, with `/catchup` tying memory, the tracker, and connectors into
one briefing. Retrieval is by the model reading the index and entries; vector recall is a later add.

## Skill sources

Stack expertise comes from skills, resolved in order: installed skills in `~/.claude/skills/` (the
bulk synced from `github.com/Mindrally/skills`, Apache-2.0), the marketplace companions, then the
discovery registries (`skillsmp.com` with its API and MCP, `awesomeskills.dev`, `crossaitools.com`)
filtered by the `skillsdirectory.com` security grade. `/synthesize` uses the registries to build an
agent for a novel task.

## Model routing and safety

Agents carry a model tier: Opus for planning, research, architecture, security, review, and
adversarial QA; Sonnet for implementation and test writing; Haiku only for the trivial. The
injection guardrail screens untrusted content before it reaches an agent or memory, and the
auto-mode classifier backs it. Nothing outward-facing happens without confirmation unless the config
authorizes it.

## Testing

The deterministic checker, the commit guard, the injection guard, the enhance hook, and the agent
and command validators have shell fixtures. Run `bash tests/run-tests.sh`.

## Docs

The design record is in [docs/](docs/): start with [docs/POLARIS_MASTER_PLAN.md](docs/POLARIS_MASTER_PLAN.md),
then the per-slice specs and plans. Release history is in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See the LICENSE file.
