# Changelog

All notable changes to Polaris. Dates are release dates; the format follows semantic versioning.

## 1.9.0 — 2026-07-28

Capture that actually happens. The journal, the work tracker, and memory all relied on an instruction
injected at session start, which the model was free to ignore, and did: twelve of thirteen journal
days sat unwritten and memory held one entry after two weeks. That work now runs on a `Stop` hook that
blocks the turn once per session, so the request has to be answered before the session ends.

New:

- **`hooks/stop-capture`, wired on `Stop`.** When a journal day is still `status: facts` or the work
  tracker has an unreconciled window, the hook blocks once and asks for the narrative, the reconcile,
  and a memory pass. It stays silent when nothing is outstanding, honors `stop_hook_active`, and
  blocks at most once per session, and only asks about journal days inside the last 14 days.
- **`/sweep`'s scalars are plugin options.** `notionParentPageId`, `timezone`, and `maxLookbackHours`
  are `userConfig` options that Claude Code prompts for at install and stores in user settings, so
  sweep no longer needs a hand-written JSON file to run. `sources` keeps its file.
- **Tool restrictions across the fleet.** All 27 agents declare `tools`; `reviewer` and `verifier` are
  read-only. `check-agents.sh` now rejects an unknown tool name, which previously dropped a
  restriction silently.
- **A model tier on all 29 commands**, matching the classes in `rules/model-routing.md`.

Fixed:

- **`/journal` read sweep config that `/sweep` deletes.** Sweep moved to user-level config and state
  in 1.8.0, and its migration strips the `sweep` key from the project config, but `/journal` and
  `journal-facts.sh` still read the old project-level paths. On any machine where sweep had run,
  `/journal` silently lost the timezone, the source queries, and the briefing backlink.
- **The work tracker reconciled the wrong session.** `session-start` advanced the cursor before the
  session did any work, so each reconcile covered the previous session and never the current one. It
  now runs at `Stop`, which is late enough to include the session's own work.
- **The `Stop` reason was not actually bounded.** `cut -c1-9500` truncates per line, not per string,
  so a busy repo produced a reason past the platform's 10,000-character cap and the harness cut the
  tail, dropping the memory instruction. It is bounded with `head -c` now, and every instruction is
  emitted before the untrusted snapshot so truncation eats data rather than the work being asked for.
- **A withheld snapshot advanced the tracker cursor**, making the window unreachable, since the
  snapshot only reads forward. The cursor now stays put whenever the snapshot is withheld, and the
  hook no longer advances it at all: the reconcile stamps it on completion, so an interrupted or
  half-done pass costs a repeated ask instead of a lost window.
- **`commands/gate.md` had no `allowed-tools`**, the only command missing it.
- **Hardening found by QA on the new hook**, all before release: the once-per-session marker is an
  atomic `mkdir` rather than a check-then-write, so eight parallel stops now block once instead of
  eight times, an unwritable temp dir makes the hook silent instead of blocking every turn, and a
  planted symlink can no longer redirect the write. An unsafe session id is rejected rather than
  mangled into a shared key. An unparseable cursor reseeds instead of handing `git log` a date it
  ignores, which returned the whole repo history as the session's delta. A two-object payload no
  longer defeats the `stop_hook_active` loop-breaker. The frontmatter scan is bounded, so a large
  journal file cannot stall session end. A screen that fails to run is reported as that, not as an
  injection attempt.

## 1.8.0 — 2026-07-28

Code has to explain itself. The comment law is now enforced by a hook rather than requested by a
rule, and no review finishes without an over-engineering pass. `/sweep` also gained an OKR lens, so
the daily briefing says whether the day's work moved a key result.

New:

- **The OKR lens in `/sweep`.** When `~/.claude/polaris-memory/okr/ledger.md` exists, the morning
  briefing gains an "OKR — today" section: each key result with its pace (behind, on track, ahead)
  from `scripts/okr-pace.sh`, and which of the day's items map to which KR. The evening block asks
  what moved, then appends a dated entry to `okr/log.md` and increments `okr/progress.json` by the
  confirmed deltas. Without the ledger the lens is off and `/sweep` behaves exactly as before,
  reading and writing nothing under `okr/`.
- `/sweep --okr-init [path]` seeds the lens from an OKR doc: it writes `okr/ledger.md` from the prose,
  extracts each KR into `okr/progress.json`, and validates the result by running `okr-pace.sh` against
  it. It refuses to overwrite an existing ledger or progress file. `/sweep --okr-review` rebuilds
  `progress.json` from the log and writes a bi-monthly review under `okr/reviews/`.
- `scripts/okr-pace.sh` — per-KR pace as JSON, computed in shell rather than judged by the model.
  `templates/okr-ledger.md` and `templates/okr-progress.json` fix the shapes both modes read.
- **The comment law.** `rules/core.md` replaces its comments policy: doc comments only, at the top of
  a file and directly above a declaration, in the language's multi-line doc syntax. No inline
  comments, none inside a function body, no narration or journal or TODO or metadata. A low comment
  count is stated as the first signal of good code, and the reader is sent to rename or extract
  before writing a comment. The one exception, a constraint the code cannot express or a ceiling
  marker, goes on its own line above the code, which overrides ponytail's trailing-marker style.
- `rules/clean-code.md` — the named smells (N1-N7 names, F1-F4 functions, G1-G36 general, T1-T9
  tests) so a finding is cited rather than argued: `F3 | src/render.ts:8 | flag argument`. Adapted
  from Clean Code chapter 17 and the MIT-licensed clean-dry-code-skills rule set, compressed and made
  language-agnostic. Loaded for code work, not injected every session.
- `hooks/guard-review` on `SubagentStop` matching the reviewer. A review that never reports the
  over-engineering axis is sent back with instructions, once per reviewer. The mandatory pass is now
  structural instead of prose an agent can skip.
- `hooks/inject-standard` on `SubagentStart`. Every code-writing and reviewing agent is a subagent, so
  the session-start injection never reached them and the standard arrived only if they read it
  themselves. The comment law and the laziness ladder now land in their context directly.
- `agents/reviewer.md` gains the over-engineering lens: reinvented stdlib, a dependency a few lines
  would replace, an abstraction with one implementation, configurability with no caller, speculative
  structure, and code the diff could delete instead of add. It runs on every review, whichever lens
  was asked for, and reports as its own axis including when clean.

Changed:

- `/sweep` config and state moved out of the project repo to `~/.claude/polaris-memory/sweep/`, and the
  OKR files to `~/.claude/polaris-memory/okr/`. `/sweep` spans every project, so its state never
  belonged in one of them, and OKR progress does not belong in a repo you push. An existing project-level
  file is migrated on the next run.
- `guard-edit` blocks instead of whispering. An inline comment in a written file returns
  `decision: "block"` with the line and what to do about it, so the edit does not stand; two strikes
  per file per session, then it degrades to advisory rather than hanging the turn. Every other
  finding stays advisory as before.
- `guardEdit` defaults to `true` in `templates/config.default.json`, and a config that omits the key
  now counts as enabled. A comment law nobody's config turns on is decoration. An explicit
  `"guardEdit": false` still disables it.
- `check-patterns.sh` gains `inline-comment` for TypeScript, Python, Go, and Rust: a comment token
  following code on the same line. URLs and full-line comments do not match.
- The reviewer's maintainability lens checks names against N1-N7 and functions against F1-F4, and
  treats a doc comment that no longer matches its code as a correctness finding, because callers act
  on it. `/flow` phase 5 and `/review-pr` step 4 mark the over-engineering pass non-negotiable.

## 1.7.0 — 2026-07-28

`/journal` now records the whole day, and every command that reads Slack reads the replies inside
threads, which none of them did before.

New:

- `/journal` pulls every source the day touched, not only the terminal: sessions and asks, commits and
  changed files, PRs authored and reviewed and issues involved in, Jira, Slack threads and DMs, Gmail,
  Calendar, Fathom, Polaris artifacts written that day, the day's `/sweep` briefing, and memory entries
  written that day. A day spent in meetings and Slack with no session here now produces an entry
  instead of nothing.
- `rules/connectors.md` — the shared protocol for reading a bounded window of work out of the
  connectors, cited by `/journal`, `/sweep`, and `/catchup` so the sequence cannot drift between them.
  Holds the Slack order, the per-source recipes, and the rule that an unavailable source is named
  rather than dropped.
- `scripts/journal-facts.sh` gained four deterministic fact types: cross-repo GitHub activity via `gh`,
  `.polaris/` artifacts dated that day, the day's sweep briefing url from `sweep-state.json`, and
  memory files written that day. `gh` runs for `/journal` and is skipped on the session-start hook
  path, so startup keeps its budget.

Fixed:

- Slack thread replies were never read. `slack_read_channel` returns channel-level messages only, so a
  reply inside a thread was invisible, and a reply under a parent older than the window was invisible
  twice over. Reproduced on live data: a reply posted at 12:37 under a parent from the previous evening
  did not appear in a channel read scoped to that day. The fix searches the user's own messages first,
  since search indexes replies, then expands every thread by its parent ts, reads each DM that moved in
  the window in full, and dedupes. This silently affected `/journal`, `/sweep`, and `/catchup`.
- `/sweep` could never resolve a Slack mention. Its resolution rule asks whether the user replied in
  the thread, and without a thread read the answer was always no, so mentions carried forever. That row
  now names `slack_read_thread` as the only admissible evidence.
- `/notes` built commit links from a hardcoded host, printed empty sections, and pre-approved the
  publish tools. Links now come from the git remote, empty sections are cut, the git facts are injected
  rather than re-derived, and publishing keeps its permission prompt as the last gate.

Docs:

- `README.md` and `CLAUDE.md` now match the code: `/journal` appears in the command table, all seven
  scripts are listed, and the architecture section names what `skills/`, `hooks/`, `rules/`, and
  `.polaris/` actually hold.

## 1.6.0 — 2026-07-27

Add `/notes`, which writes the release notes a person would be proud to send, for two audiences at
once.

New:

- `/notes [version]` command — detects the change source (a `dev`-style branch ahead of `main`, else
  the latest tag to `HEAD`, else the last 50 commits), shows the commit count, file count, and date
  span, and stops for confirmation before reading further; a project that ships by merged-PR window,
  tag pair, or Jira fix version says so at that prompt. It then reads the diff behind each change
  rather than trusting commit messages, classifies each one, and writes two documents to
  `.polaris/releases/`: one for the dev team and client, with breaking changes and migrations above
  the feature list, and one for the people who use the product, written to an ICP the `researcher`
  agent establishes and states at the top so the sender can correct it. An entry that cannot say what
  the reader can now do is filed internal-only instead of padded. Publishing to a GitHub release,
  Notion, or Slack happens only after confirmation, never in the same turn as the offer.

`/release` is unchanged — it still cuts the version, changelog, and tag.

## 1.5.0 — 2026-07-21

Add `/sweep`, a deep start-of-day and end-of-day briefing that succeeds `/catchup` for when a fast
skim is not enough.

New:

- `/sweep` command — pulls Gmail, Slack, Jira, Fathom, and Calendar in full over a bounded window,
  extracts every action item and buried signal (an offhand client remark in a transcript, say) into
  two tiers, groups them by configured lists, carries unresolved items forward between runs, and
  writes one dated Notion subpage per run. Configured once via a `sweep` block in
  `.polaris/config.json`; run manually at a calendar block, no cron. `--dry-run` renders the briefing
  to stdout without writing.
- `scripts/sweep-window.sh` — deterministic pull-window helper (since-last-run, 24h first-run
  fallback, 7-day cap), so the command does no date math itself. Covered by unit tests, including a
  first-run fallback on a corrupt or future cursor.

`/catchup` is unchanged — it stays the fast, transient briefing.

## 1.4.0 — 2026-07-20

Adopt the useful pieces from an external-skill review (the recent.design skill set, claude-mem, and
obsidian-second-brain) into Polaris-native form, and tighten the fleet's skill wiring. A gap analysis
kept only what Polaris did not already do: most sources duplicated existing agents and skills or clashed
with the markdown-and-shell constraint, so the work adds one skill, a memory convention, a motion
baseline, and one validation check.

New:

- `extract-design-system` skill — reverse-engineer a design system from a live URL into a DESIGN.md
  token set. A thin wrapper over the external `npx` engine, invoked on demand; feeds `ui-new` and the
  `ui` agent. Covers the one design gap the ui layer lacked (tokens from a live site, versus impeccable's
  `extract` from project code).

Memory:

- Freshness markers on memory entries — `timeless`, `dated`, or `pointer` (a missing value reads as
  `timeless`). Recall re-verifies a `dated` fact and weighs its age, and checks the source behind a
  `pointer` rather than trusting the stored copy.
- `/remember` now checks for a duplicate by grepping entry bodies, not only the `INDEX.md` descriptions,
  so a near-duplicate worded differently no longer slips through.

Design baseline:

- Motion craft folded into the ui baseline (`rules/stacks/react.md`, `agents/ui.md`): motion earns its
  place, duration by size and role, easing by direction, motion starts where the interaction happened,
  stays interruptible, and honors `prefers-reduced-motion`.

Tooling:

- `check-commands.sh` validates that every agent `skills:` token resolves to a local skill or command,
  or a companion declared in `companions.json`, so a mistyped or renamed skill fails the suite instead of
  passing silently. `companions.json` gains `companionSkills` (the fleet's external skill contract) and
  an `optionalCompanions` entry for `shadcn` (declared, deliberately not auto-installed).

## 1.3.0 — 2026-07-19

Adapt ideas from `mattpocock/skills` and `ayghri/i-have-adhd` (both MIT) into Polaris-native form.
A gap analysis kept only what Polaris did not already do: most of the source skills duplicated
existing agents and commands, so the work adds four new pieces and folds the rest into what exists.

New:

- `/recon` — plan a large, foggy effort as a shared decision map of open questions before any spec
  or code. Typed decision tickets (research, grilling, prototype, task), a frontier of unblocked
  tickets, and one decision per session. Runs before `/flow`.
- `/domain` — model the domain into a ubiquitous-language glossary (`CONTEXT.md`) and a numbered
  `docs/adr/` decision ledger, written inline as terms resolve, with a three-gate filter on what
  earns an ADR.
- `/route` — route a situation to the one right Polaris command and say why.
- `merge-conflicts` skill — resolve an in-progress merge or rebase by intent, hunk by hunk, running
  the quality gate before finishing.

Folded into existing agents and commands:

- `product`: the spec now names its testing seams, resolves facts by looking them up instead of
  asking, and captures domain terms into the glossary as they settle.
- `reviewer` and `/review-pr`: a spec-conformance lens that checks the diff against acceptance
  criteria as an axis separate from the quality lenses.
- `architect`: a three-gate ADR filter and a numbered `docs/adr/` ledger.
- `audit-refactor`: rank targets by git churn before the full scan.
- `/triage`: a `ready-for-agent` versus `ready-for-human` lifecycle state.
- `/handoff`: a secret and PII redaction pass, plus a suggested-skills line.
- `/onboard`: a resumable learner-progress ledger across sessions.
- The writing standard and output style: an answer-first response shape.

## 1.2.3 — 2026-07-16

- Escape the session-start context with `jq` instead of bash, cutting startup from 19 seconds to 0.4.

## 1.2.2 — 2026-07-16

- Add `/journal`: write or regenerate a day's journal on demand, with automatic journaling of the
  previous day on the first session of a new day, backed by a daily-facts extractor.
- Auto-maintain the work tracker and log every `/flow` run.
- Give every agent a role-specific Expertise section.
- Add a craft-principles rule, injected every session.
- Extend the quality gate to Python, Go, and Rust, and harden the injection screen.
- Run the test suite on every push and pull request.
- Fix the session-start crash and the 30-second startup hang: run the companion install once rather
  than on every session, with regression tests and a recorded RCA.
- Add the missing `/audit` command and stop linting code fences as prose.

## 1.2.1 — 2026-07-15

- Add a "Using Polaris" guide to the README: the platform organized by job, not by tool, with the
  one command to run for each situation and how to get the best result from it (ship a feature, fix
  a bug, check work before it ships, understand or clean up a codebase, harden and upgrade, plan and
  triage, release, stay oriented across sessions).

## 1.2.0 — 2026-07-15

Seven operational modes that ride the fleet, gate, and guardrails:

- `/modernize` (dependency and framework upgrades), `/harden` (security pass), `/review-pr` (review
  an existing PR), `/triage` (classify a batch of bugs or issues), `/release` (cut a release),
  `/docs-drift` (fix docs that no longer match the code), and `/spike` (a timeboxed throwaway
  prototype to answer a feasibility question).

## 1.1.0 — 2026-07-15

- Add `/debug`, the bug lifecycle: an intake interview, grounding in the code and the stack (fresh
  docs and the DB schema), a real reproduction, root-cause analysis that names the class of bug, a
  class-level fix, verification, a regression test, and an RCA. The bug counterpart to `/flow`.
- Add `/incident`: production incident to blameless postmortem, stabilize before diagnosing.
- Forbid AI attribution in commits, PRs, and code (no `Co-Authored-By` for the AI, no
  "generated with" byline); the commit hook enforces it.
- Wire skill resolution to the sources: installed skills, marketplace companions, then the discovery
  registries filtered by security grade. Add the ponytail companion and its laziness ladder.
- Rewrite the README as the full front door.

## 1.0.0 — 2026-07-15

First stable release. Polaris is now an all-in-one project operating system for Claude Code: the
full SDLC plus product, research, marketing, and ops, held to one quality bar with anti-slop prose,
built across ten subsystems. This release also:

- Deepens all 27 fleet agents from thin stubs into senior-practitioner definitions with concrete
  per-role checklists, failure modes, and techniques.
- Adds the **ponytail** minimalism companion and its laziness ladder to the standard, so code
  writers build the least code that works; it auto-injects into every subagent.
- Adds `rules/routing.md`, a task classifier that maps each task to the agent, command, ponytail
  intensity, and model tier to use.
- Completes `companions.json` as the full manifest of every marketplace, plugin, skill source, and
  discovery registry.
- Fixes the SessionStart hook permission error by making the hook scripts executable.

Everything below shipped in the lead-up to this release.

## 0.11.0 — Dynamic agent synthesis (H)

- `/synthesize`: compose an ephemeral agent from the skill registries for a task no fleet agent
  covers, with a security-grade trust filter and the injection guardrail applied.

## 0.10.0 — Persistent memory (E)

- Global file-based memory at `~/.claude/polaris-memory/` with `rules/memory.md` conventions,
  session-start bootstrap and surfacing, and `/remember`, `/recall`, `/catchup`.
- `/catchup` briefs across memory, the work tracker, and connectors (wired protocol-ready).

## 0.9.0 — Prompt enhancing (F)

- A gated judge-then-enhance `UserPromptSubmit` hook (off by default) and `/enhance`.

## 0.8.0 — Work tracker (E flagship, MVP)

- `.polaris/work/streams.md` surfaced at session start, updated by `/track`, screened for injection.

## 0.7.0 — Orchestration cycle and standalone modes (D, G)

- `/flow`: the idea-to-shipped cycle across the fleet, gated at spec, design, and plan, with capped
  verify loops.
- `/research`, `/onboard`, `/explain` standalone modes. A command-to-agent reference check.

## 0.6.0 — Agent fleet (B)

- 27 role agents across every SDLC phase and domain, each following one contract, wiring skills, and
  carrying a model tier. An agent-frontmatter validator.

## 0.5.0 — Model routing and injection guardrail (J, I)

- `rules/model-routing.md` and matching agent tiers.
- `guard-input`: flags prompt-injection markers in fetched and MCP tool results.

## 0.4.0 — Handoff and audit docs (C)

- `/handoff` (feature and audit variants), the strict `prod-audit` agent, and the enforced
  `.polaris/` doc layout.

## 0.3.0 — Quality foundation (A)

- One canonical standard (`core.md`, `writing.md`, stack overlays, `patterns.json`), the
  `quality-gate` skill and `/gate`, the writing output style, the commit/PR and edit guards, the
  setup interview and companions. Merged the cleanup agents; retired the legacy rule files.

## 0.2.0 and earlier

- The original design-intelligence plugin: UI skills, stack detection, and the first quality agents.
