# What Polaris should build next

Date: 2026-07-15
Author: research mode (`/research`)

## The question and the decision it feeds

Polaris is at version 1.2.1. The master plan marks all ten subsystems (A through J) as built and
shipped in 1.0.0. So the decision is not "what large subsystem is missing" but "given a
feature-complete-on-paper system that runs solo on `main` with no feature branches, which next
change buys the most reliability, honesty, or capability per unit of effort." A good answer names
concrete gaps between what the repo claims and what it does, ranks fixes by value against effort,
and separates verified facts from my inference.

I read the codebase (agents, commands, hooks, scripts, rules, the master plan), ran the test suite,
ran the mechanical checker over Polaris's own prose, and checked the plugin ecosystem for prior art.
Connectors carry no demand signal for a solo project, so I did not force one; that absence is noted,
not treated as a finding.

## What exists, verified

- 27 agents (`agents/*.md`), 22 commands (`commands/*.md`), 5 local skills, 5 hooks, 4 scripts.
- The quality gate is a skill (`skills/quality-gate/SKILL.md`) that calls a deterministic checker
  (`scripts/check-patterns.sh`) plus a model judgment pass.
- The test suite (`tests/run-tests.sh`) passes: 18 checks green, covering the pattern checker, the
  commit guard, the injection guard, the enhance and edit hooks, and two validators.
- The mechanical prose checker run over Polaris's own `agents/`, `commands/`, `README.md`, and
  `CLAUDE.md` returns 0 findings. Its dogfooding holds at the mechanical level today.

## Findings and proposals, ranked

### 1. Put the test suite and broadened validators in CI (top recommendation)

**Problem.** There is no `.github/` directory and no CI of any kind (verified: `ls .github` finds
nothing). `tests/run-tests.sh` runs only when someone remembers to run it. The project policy is
"all work on `main`, no feature branches" (`MEMORY.md`, master plan §13), so every commit lands on
the release branch with no automated check. A shell edit that breaks `guard-commit-pr` or
`check-patterns.sh` ships silently until the next manual run.

**Compounding gap: validator coverage.** `scripts/check-commands.sh` validates backticked agent
references in `commands/flow.md` only. The other 21 commands are unchecked, and no script validates
the `skills:` frontmatter on any of the 27 agents. `scripts/check-agents.sh` prints
`warn: no skills field` but never confirms that a named skill (for example the five the `ui` agent
wires: `impeccable, ui-ux-pro-max, huashu-design, design-taste-frontend, frontend-design`) actually
resolves. A typo in a skill or agent reference anywhere outside `flow.md` is caught by nothing.

**Reasoning.** These two are one PR: a GitHub Actions workflow that runs `tests/run-tests.sh` on
push and pull request, plus an extension of the validators to cover all commands and every agent's
`skills:` list against the installed and companion skill inventory. Polaris preaches "verify after,
loop until the check passes" (`core.md`). Right now the check exists but never runs itself. The fix
turns dogfooding from a claim into an enforced fact and closes the reference-typo hole across 49
files instead of one.

**Evidence.** `ls .github` (absent); `scripts/check-commands.sh` (the `grep` targets `flow.md`
alone); `scripts/check-agents.sh` (the skills line is a `warn`, not a failure); the confirmed
grounding note in the task.

**Effort.** S for CI wiring, M with the validator broadening. Confidence: high.

### 2. Scope the ask-first rule so code-writing agents infer instead of pausing

**Problem.** `core.md:122` states the rule for every agent: "If something is unclear, stop and
ask." The agent contract in each code writer inherits it (see `backend.md`, "Think before coding"),
and 18 of 27 agent files contain "ask" language. There is no distinction between an upstream agent
that should clear assumptions (product, ux) and a code writer that should pick a sensible default
and verify. This contradicts the maintainer's confirmed near-term direction: infer-first autonomy
for code-writing agents (backend, frontend-logic, ui, feature-builder, integrations, data-*), with
product, design, and the `/flow` gates staying ask-first.

**Reasoning.** The change is a rule edit plus targeted agent edits, not new machinery. Split the
`core.md` "stop and ask" clause into two: upstream and gated work asks; code-writing agents infer a
default, state the assumption, and loop to a verifiable success check before pausing. Add an
"infer-first" line to the contract of the six named code writers, and note the boundary in
`flow.md` so the upstream gates stay intact. This is behavior change across the fleet from a small
diff, which is why it ranks second.

**Evidence.** `core.md:119-122`; `backend.md` contract section; the routing table in `routing.md`;
the maintainer direction in the task grounding.

**Effort.** M. Confidence: high.

### 3. Strengthen the injection guard beyond a 9-phrase literal match

**Problem.** The master plan positions subsystem I as a safety layer that justifies auto-install and
connector access (§4.3). The actual guard (`guard-input`, driven by `patterns.json`
`injection.phrases`) is a `grep -F` over nine fixed English strings: "ignore previous
instructions", "you are now", "system prompt", and six more. A payload that says "please disregard
the earlier guidance" or writes in another language passes clean. The test fixture
(`injection-bad.txt`) contains one of the exact phrases, so the green test proves only that literal
matching works, not that injection is caught.

**Reasoning.** The gap between the claim ("detects instruction-override, tool-use hijacking, and
exfiltration prompts") and a nine-string denylist is the kind of security theater the Polaris
standard exists to prevent. Two grounded options: keep the mechanical pass as a fast pre-filter but
route flagged-or-long untrusted content through a model classification step in the hook (the plan
already describes subsystem I as a classifier, not a denylist), or at minimum expand the phrase set
and add paraphrase and non-English fixtures so the test measures real coverage. I recommend the
model-classification path because the denylist cannot be made complete by adding strings.

**Evidence.** `rules/patterns.json` (`injection.phrases`, 9 entries); `hooks/guard-input`
(literal grep); `tests/fixtures/injection-bad.txt` (contains a listed phrase); master plan §4.3.

**Effort.** M. Confidence: high on the weakness, medium on the remedy shape.

### 4. Run `/docs-drift` on the master plan: "all Built" overstates the repo

**Problem.** The master plan §3 table marks subsystems E through J "Built" and says "All subsystems
shipped in the 1.0.0 release." Several concrete pieces the plan promises are absent from the repo:
no `monitors/monitors.json` (§11 observability), no statusline or OpenTelemetry spend meter (§11
cost control), no LSP-server integration feeding the gate (§10), no `/schedule` command or routines
(§5, §10.1), no embeddings RAG memory, and no connector activation. The README hedges honestly in
places ("vector recall is a later add"), but the plan's status table does not.

**Reasoning.** Polaris ships a `/docs-drift` mode whose whole job is finding docs that no longer
match the code. Turning it on its own plan is cheap, dogfoods the tool, and keeps the roadmap
honest so future "what to build next" reads from a true baseline. Change the §3 status column to
distinguish shipped from designed-but-unbuilt, and move the absent pieces into a clearly labeled
"designed, not yet built" section rather than leaving them as "Built."

**Evidence.** Master plan §3 table (rows marked Built) and §11 (promises monitors, statusline, OTel
meter); `ls monitors` and statusline search (absent); no `/schedule` in `commands/`.

**Effort.** S. Confidence: high.

### 5. Extend gate coverage: non-TypeScript mechanical rules and judgment-pass fixtures

**Problem.** The deterministic checker only carries TypeScript code rules (`patterns.json` has a
single `code.ts` block: `as any`, `@ts-ignore`, `console.log`, `TODO`). Python, Go, and Rust
projects, which the stack overlays and the fleet claim to support, get no mechanical code pass at
all, only the prose pass and the model judgment pass. The judgment pass itself, which does the real
work (root-cause versus symptom, one-file-one-responsibility, duplication), has no fixtures, so a
regression in the gate's reasoning instructions would not be caught by any test.

**Reasoning.** The gate is the engine every agent calls before declaring done. Its coverage skewing
to one language is a real hole for a system that markets itself as stack-aware. Add a small set of
per-language mechanical rules (bare `except:` in Python, ignored errors in Go, `unwrap()` in Rust
hot paths) and a few golden-file fixtures for the judgment pass so its output can be regression
tested. Scope this to the languages the maintainer actually ships in first, rather than all at once.

**Evidence.** `rules/patterns.json` (only `code.ts`); `tests/fixtures/` (TS and prose fixtures only,
no judgment-pass cases).

**Effort.** M. Confidence: high.

### 6. Ship the maintenance track: a `/schedule` routine and monitors

**Problem.** The plan's maintenance track (§5) and command surface (§10.1) promise routines: a
nightly audit, a weekly dependency and docs-drift check, a PR-triggered review, all running "with
the laptop closed." Neither `/schedule` nor `monitors/monitors.json` exists. The harness now exposes
`loop` and `schedule` skills, so the underlying primitive is available.

**Reasoning.** This is the one proposal where I flag the demand honestly. For a solo project on
`main`, an unattended nightly audit has speculative value; the same laziness ladder Polaris enforces
argues against building scheduling machinery before there is a job that needs it. Doing nothing here
is viable and possibly correct for now. If built, the cheapest useful version is a single documented
`/schedule` recipe that wires the existing `/audit` and `/docs-drift` commands to the harness
scheduler, not a new subsystem.

**Evidence.** Master plan §5 and §10.1; `commands/` (no `schedule`); `ls monitors` (absent).

**Effort.** M. Confidence: medium (build), high (that it is currently absent).

### 7. Statusline spend meter (lowest priority)

**Problem.** Plan §11 scopes a live cost meter reading OpenTelemetry `claude_code.cost.usage` into a
statusline, since the Opus-heavy adversarial phases and the fan-out fleet can run up real spend. It
does not exist.

**Reasoning.** The plan's own note says there is no built-in "stop at $X per run" in the CLI, so a
useful version needs OTel wiring plus a statusline script plus a watch loop, which is L effort with
uncertain payoff for one user. Recommend deferring until the fleet is run at scale enough that spend
is a felt problem. Doing nothing is the right call today.

**Evidence.** Master plan §11 (cost control, statusline); no statusline script in the repo.

**Effort.** L. Confidence: medium.

## Ranking summary

| # | Proposal | Effort | Value | Confidence |
|---|---|---|---|---|
| 1 | CI + broadened validators | S–M | High | High |
| 2 | Infer-first for code-writing agents | M | High | High |
| 3 | Real injection classification, not a denylist | M | High | High / med |
| 4 | Docs-drift the "all Built" master plan | S | Medium | High |
| 5 | Non-TS gate rules + judgment fixtures | M | Medium | High |
| 6 | `/schedule` routine + monitors | M | Medium | Medium |
| 7 | Statusline spend meter | L | Low now | Medium |

## What remains uncertain

- Whether Claude Code hard-fails on a broken plugin `skills:` reference at load time or only warns.
  If it hard-fails, proposal 1's validator is still worth it as a pre-commit check but is less
  urgent. This is checkable against the current plugin-loading docs.
- The exact set of code-writing agents the maintainer wants switched to infer-first. I used the six
  named in the task grounding; confirm before editing.
- Whether the injection guard should classify every untrusted result or only long or flagged ones,
  which the plan lists as an open question (§14). That decision shapes proposal 3's cost.

## Prior art checked

The Claude Code ecosystem has comparable SDLC frameworks: SuperClaude (commands, agents, modes,
session memory), claude-flow (orchestration), and the agentic-sdlc-plugin (10 commands, an 8-agent
QA loop, a self-expanding test suite). Polaris already matches or exceeds their surface. None of the
three appears to run its own markdown through a self-enforced quality gate in CI, which is where
proposal 1 makes Polaris distinct rather than merely another agent bundle.

Sources:
- [SuperClaude review](https://vibecodinghub.org/blog/superclaude-review)
- [agentic-sdlc-plugin](https://github.com/ajaywadhara/agentic-sdlc-plugin)
- [awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit)
