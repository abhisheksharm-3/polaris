# Work streams

<!-- The Polaris work tracker for this project. Surfaced at session start; updated by /track. -->
<!-- Keep active and blocked streams at the top. Move finished ones to the Done archive. -->

## tracker-clobber — two sessions reconciling one file lose each other's work

- domain: bug
- status: open, root cause known and not fixed
- state: Found 2026-09-07. `hooks/stop-capture` asks every session to reconcile
  `.polaris/work/streams.md` on every Stop, and the run ledger is deliberately per-session so two
  conversations run in parallel. The tracker is not. Commit 11643fb committed a copy of the file
  that predated 5fc428d and silently dropped the `plugin-audit` and `worktracker-snapshot` streams
  5fc428d had added; a third stream, `router-questions`, existed only in a working tree and is gone
  entirely. Recovered the two committed ones with `git show 5fc428d:.polaris/work/streams.md`. The
  ledger solved exactly this problem by keying on `CLAUDE_CODE_SESSION_ID`, and the tracker did not.
- next: decide the shape before writing code. Either the reconcile appends to a per-session file
  that a later pass merges, the way the ledger keys its pointer, or `stop-capture` re-reads and
  patches rather than rewriting, or only one session per project is asked to reconcile at all. The
  cheapest correct version is probably per-session append plus a merge in `/track`.
- files: hooks/stop-capture, .polaris/work/streams.md, scripts/run-state.sh (the pattern to copy)
- touched: 2026-09-07 (found by losing two streams to it)

## router-misroutes — a regex table over natural language, and what being wrong costs

- domain: bug
- status: two thirds fixed and shipped, one third filed
- state: Measured 2026-09-07 over 96 real run-opening prompts drawn from `~/.claude/history.jsonl`,
  not fixtures. Three failure modes: 24 of them, a quarter, opened with also/and/ok/ya/now/still and
  belonged to a conversation already under way; 10 were questions; and 10 landed in `audit`,
  `research` or `qa` because the flow name is an ordinary domain noun in the work being described,
  as in "show all audit log events" or "make deepseek the main for qa". True misroute rate is
  roughly 45 to 60 percent, against a felt rate the user put at 95, and that gap is the finding: a
  correct route is silent while a misroute opens a run, blocks Stop, and nags every turn until
  someone runs /polaris:pause. The asymmetry was the bug, not the accuracy.
  Fixed in 11643fb (questions reach `conversation`) and 98d7ed8: a continuation marker now decides
  whether to seed while the class still decides what the work is, and a run that records no phase
  drops itself after three asks and archives to `.done/`. 364 assertions.
- next: the noun collision is the part no regex settles, because distinguishing "audit the codebase"
  from "the audit log" is distinguishing an instruction from a topic. Requiring a verb plus a
  codebase-shaped object will fail differently rather than less. This is where the triage plan's
  open question comes due: whether prompt classification belongs in a regex table at all. Decide
  that before adding a ninth pattern to `audit`.
- files: rules/patterns.json, hooks/enhance-prompt, hooks/advance-flow, scripts/route-prompt.sh
- touched: 2026-09-07 (measured, two thirds shipped, noun collision filed)

## plugin-audit — hold the whole plugin to the current Claude Code contract

- domain: audit
- status: active, audit approved and triaged, on the fix phase
- state: Opened 2026-09-05 from the user's ask to audit every feature against
  `code.claude.com/docs/llms.txt` and argue what should change. Run `see-entirelty-of-this` on the
  audit flow; phase `audit` is recorded against
  `.polaris/reports/2026-09-05-plugin-audit.md`. The suite passes 277/277, so none of this is a
  test failure. Four gates were measured and do not gate: the model floor allows any full model id
  because `model-floor.json` ranks only the three aliases, `guard-edit` blocks on `PostToolUse`
  which the hooks reference says cannot block, `guard-commit-pr` catches only a double-quoted `-m`,
  and `skills/ui-{new,polish,prototype}` are 116,748 bytes whose 42 referenced paths do not exist.
  The router was measured against 800 real prompts from `~/.claude/history.jsonl` and placed 9% of
  them; the `unknown` branch then costs 895 bytes on every prompt. SessionStart injects 62,985
  bytes, of which the uncapped memory index is 33,475. 17 of 27 agents have never been dispatched.
  `args.level` is read by all three workflows and passed by nothing, so every review runs at `high`.
  The verification fan-out then found the finding that reframes the rest, and it was confirmed from
  this session's own transcript: `session-start` emits 62,985 bytes into a documented
  10,000-character cap, so the model gets a 2KB preview and a file path. The comment law, the whole
  of craft.md and writing.md, the memory index and the tracker slice are all past the cut, every
  session and every clear. That inverts the cost claim, which was wrong and is corrected in the
  report: none of it is billed because none of it arrives. It also explains why the comment law had
  fired in 2 sessions of ~904. A second dead gate came out of the same pass: `guard-phase:55` reads
  `.tool_input.effort`, and the Agent tool has no `effort` parameter, so `effort-floor.json` and its
  four assertions gate a key that never arrives.
- next: audit approved 2026-09-07 and `triage` recorded, so the run is on `fix`. Take T0 and T1 from
  the triage plan and nothing else: T0 is the payload split plus a size assertion, T1 is the five
  gates. `rules/core.md` is 10,135 B and busts the cap alone, so T0 is a resident-versus-on-demand
  split of the rules rather than a ceiling on the memory index. T2 onward want their own runs.
- files: .polaris/reports/2026-09-05-plugin-audit.md,
  .polaris/plans/2026-09-07-audit-triage.md, .polaris/runs/see-entirelty-of-this/state.json
- touched: 2026-09-07 (audit approved, triage recorded, both artifacts amended once each)

## worktracker-snapshot captures injected text, not the user's prompt

- domain: bug
- status: open, observed twice and not investigated
- state: The `Asked:` line in the Stop-hook snapshot arrives full of harness payload rather than the
  prompt. On 2026-09-05 it carried the `/effort` command stdout and the entire workflow-authoring
  skill reference; on 2026-09-07 it carried a task-notification XML block including
  `<task-id>`, `<result>`, and the workflow failure list. Both times the user's actual question was
  buried or absent, so the reconcile it asks for is working from the wrong text.
- next: read `scripts/worktracker-snapshot.sh` and find where the prompt is taken from; it appears to
  read whatever reached the model rather than the typed prompt. `~/.claude/history.jsonl` holds the
  typed prompt with its project and timestamp and would be the cleaner source.
- files: scripts/worktracker-snapshot.sh, hooks/stop-capture
- touched: 2026-09-07 (noticed during the plugin audit; not filed as an audit finding because it was
  observed rather than measured)

## deck-mode — a slidev presentation mode driven by a description

- domain: feature
- status: active, designed and not built
- state: Opened 2026-08-22 from the user's ask for a mode where they describe the deck they want and
  Polaris produces it, built on sli.dev. Design is done and the artifacts are on disk but uncommitted:
  `.polaris/specs/deck-mode.md`, `.polaris/plans/deck-mode.md` carrying 8 numbered tasks in dependency
  order, and a new `docs/adr/` holding three ADRs that all pass the prose check. ADR 0001 scaffolds
  slidev at run time rather than vendoring an offline copy. ADR 0002 puts decks at
  `.polaris/decks/<date>-<slug>`. ADR 0003 makes the theme gate seven mechanical checks read from
  source. Three decisions failed the three-gate test and stayed in the plan rather than becoming
  ADRs, the package-manager order among them (pnpm, yarn, bun, npm, deno). The plan answers the four
  open questions the design left, including scaffold failure: `deck-scaffold.sh` exits 3, 4, 5 and 6
  for no manager, a Node version under the floor, and the two create failures.
- next: the plan names three places where the design and the acceptance criteria disagree, in a
  section of its own, and those have to be settled before task 1. Then build, starting with the
  scaffold script. Nothing is committed; every file above is untracked.
- files: .polaris/specs/deck-mode.md, .polaris/plans/deck-mode.md,
  docs/adr/0001-scaffold-slidev-at-run-time.md, docs/adr/0002-decks-under-polaris.md,
  docs/adr/0003-theme-checked-from-source.md
- touched: 2026-08-22 (plan and three ADRs written; not built, not committed)

## frontend-design-rules — a design baseline the ui agent and the stack overlays share

- domain: feature
- status: active, work in progress and stashed
- state: A new `rules/frontend-design.md` plus edits to `agents/ui.md`, `skills/ui-polish/SKILL.md`,
  `rules/stacks/nextjs.md` and `rules/stacks/react.md`, from the user's ask to add five rules and fix
  two bugs alongside them. The whole changeset was stashed on 2026-08-25 as `stash@{0}`,
  "wip: deck-mode, ui/frontend-design rules", untracked files included, to clear the tree for the
  `/oneonone` work. The five rules and the two bugs are not recorded anywhere outside that stash.
- next: pop `stash@{0}` and write down what the five rules and the two bugs actually are before
  anything else touches those files, because a stash is the only record of them.
- files: rules/frontend-design.md, agents/ui.md, skills/ui-polish/SKILL.md,
  rules/stacks/nextjs.md, rules/stacks/react.md
- touched: 2026-08-25 (stashed as stash@{0}, unread)

## flow-enforcement — make routing bind instead of suggest

- domain: feature
- status: active
- state: All eleven tasks are built and committed, version 1.10.0 in both manifests, suite at 185
  assertions. `rules/flows.json` holds eighteen flows, each an ordered phase list, with
  `scripts/check-flows.sh` asserting every target resolves. `scripts/run-state.sh` is the ledger: a
  phase is done only with its artifact on disk and its hash matching, one open run per session.
  `hooks/enhance-prompt` classifies every prompt against the `routing` array in
  `rules/patterns.json` and opens the run; `/polaris:compose` builds a flow from
  `scripts/inventory.sh` when no row fits, validated and gated like a catalog row. Four gates read
  the ledger: `guard-phase` refuses an out-of-phase dispatch and one below the floor in
  `rules/model-floor.json`, `guard-command` refuses a phase command whose predecessor is unearned,
  and `advance-flow` drives the run at `Stop`. The fourth gate, the small-model clarity veto, was
  deleted on 2026-08-03: it false-stopped a real question, cost a model call on every prompt, and
  had no off switch short of editing `hooks.json`. The suite now asserts no prompt-type input hook
  returns. Three workflows under `workflows/` hold the fan-out. `/polaris:pause` clears a run and
  `scripts/statusline.sh` shows it.
  The docs now match that shape: a 2026-08-03 drift pass rewrote `commands/flow.md` from eleven
  prose phases down to 44 lines that defer to the `feature` row, documented the `runs/<slug>/`
  layout in `rules/doc-organization.md`, added the six missing rows to `commands/route.md`, and
  brought `CLAUDE.md` up to the shipped architecture. 1.10.0 is dated in `CHANGELOG.md` with
  release notes in `.polaris/releases/2026-08-03-v1.10.0.md`.
- next: two gaps, both needing a live session rather than the suite. An observed deny: every
  `guard-phase` and `guard-command` assertion is a hand-built payload, and the `Task` versus `Agent`
  matcher bug is exactly what that gap produces. And whether `SubagentStart` fires for
  workflow-spawned agents, which decides whether `inject-standard` reaches them; answering it means
  running `/polaris:verify` once. That question is now a cost question as well as a correctness one,
  so the `token-efficiency` stream depends on its answer. Part of that is now answered: the
  2026-08-09 dispatch probe showed a workflow `agent()` reaches no hook at all, so
  `inject-standard` cannot reach a workflow-spawned agent. The main-loop `Agent` path does fire
  `guard-phase`. The newest installed plugin is `polaris/1.13.0/`, level with the tree.
- files: rules/flows.json, rules/model-floor.json, rules/patterns.json, rules/routing.md,
  scripts/check-flows.sh, scripts/route-prompt.sh, scripts/run-state.sh, scripts/inventory.sh,
  scripts/statusline.sh, hooks/enhance-prompt, hooks/guard-phase, hooks/guard-command,
  hooks/advance-flow, hooks/hooks.json, commands/pause.md, commands/compose.md, commands/flow.md,
  CLAUDE.md,
  workflows/verify.js, workflows/review.js, workflows/build.js,
  tests/fixtures/routing-cases.txt, tests/run-tests.sh, templates/config.default.json,
  README.md, CHANGELOG.md, .claude-plugin/plugin.json, .claude-plugin/marketplace.json,
  docs/specs/2026-08-01-flow-enforcement.md, docs/plans/2026-08-01-flow-enforcement.md,
  .polaris/runs/2026-08-01-flow-enforcement-preflight.md
- touched: 2026-08-22 (parallel runs released as 1.15.0; body last built 2026-08-01)
- 2026-08-17, released as 1.15.0 on 2026-08-22: the ledger holds one run per session rather than one per
  project, so two conversations in one repo no longer refuse each other. `scripts/run-state.sh`
  keys its pointer at `.polaris/runs/.open-<session id>` from `POLARIS_SESSION` or
  `CLAUDE_CODE_SESSION_ID`; a live probe confirmed a subagent inherits that id unchanged, which is
  what keeps a gate and the agent it gates reading one run. `seed` now refuses a second run in the
  same session and refuses a slug whose directory another session owns, since two conversations
  writing one `state.json` is the race the hash invariant cannot survive. A run left at the old
  shared `.open` path is adopted by the first session that asks, proved on the live
  `token-efficiency` run, which migrated and still reads phase `build`. Five new assertions in
  `tests/run-tests.sh` cover parallel seeds, the per-session limit, the slug collision, a `clear`
  that does not reach across sessions, and the adoption. Suite at 277 assertions, 0 failures.
  Known cost: nothing reaps a pointer whose session ended, so an abandoned run now sits on disk
  invisibly where the single `.open` used to force a decision.
- next, for this stream: 1.15.0 is tagged and released, so a `/plugin` update makes parallel runs
  live. Nothing reaps a pointer whose session ended, which is recorded as a known limit rather than
  solved; revisit if abandoned runs actually accumulate. The two older gaps still need a live session: an
  observed `guard-phase` deny rather than a hand-built payload, and the `Task` versus `Agent`
  matcher bug that gap produced.
- found 2026-08-09, a defect: `advance-flow` keys its once-per-transition marker on
  `${session}-${slug}-${phase}-${status}`, and `status` moves from empty to `done` inside a single
  phase, so every phase blocks twice rather than once. A four-phase `feature` run is eight `Stop`
  blocks. The fix is to drop `status` from the key. This is the mechanical half of the user's report
  that the hooks fire too often and interrupt work; the clarity veto in `token-efficiency` is the
  other half.
- open question, for a human: `docs/POLARIS_MASTER_PLAN.md` still calls `/flow` the full
  orchestration cycle at line 822 and describes that cycle at line 794. Left as written on the
  argument that a plan records intent and rewriting it erases the history. Decide addendum or
  leave.

## sweep-briefing-format — restructure what /sweep emits

- domain: feature
- status: shipped as 1.14.0
- state: The spec is written and was recorded: `.polaris/specs/sweep-briefing-format.md`, 503 lines,
  `check-patterns.sh prose` exit 0. The run then reached its approval stop and was cleared with
  `scripts/run-state.sh clear` to free the one-open-run slot for `review-levels`, so the ledger no
  longer holds it. The spec file is untracked but on disk. The request is structure and information
  density, not which sources are read. The evidence is one real briefing: 40 bullets under a single
  `Act on this` heading with no priority order, four preamble blockquotes and three closing essays
  that restate the bullets, deadlines stated in prose with nothing collecting them by date, and
  `day N` ages that nothing escalates on. The spec file is tracked as of `0d8c73f`, no longer
  untracked on disk.
- 2026-08-17: the spec was rendered against a real 66-hour briefing as a sample, in the scratchpad
  at `sweep-sample-2026-08-17.md`. Three defects in the spec surfaced that no reading of it found.
  R2 ranks `feat/enhanced-script-generator` — 60 commits, no PR, a repo that has never run CI, and
  the old page's own top item — as `no-date`, so it lands 14th of 16 inside a collapsed toggle;
  either `decaying` widens to cover unreviewed-and-unguarded work or R2 needs an eighth band. R4's
  `Dated` range reads "within the window's end plus seven days", which excludes an overdue date,
  and the sample had one 13 days past. The format did surface that overdue date, SAGE-259's
  `HARD DATE: 2026-08-04`, which the old page had buried inside a "backlog, none moved" bullet.
- 2026-08-17, a new reference: the user shared Dia's Monday Brief and likes it, with the caveat
  that it is thin. Three things it does that the spec does not: one hero action instead of a ranked
  seven, a numbered `New updates` list of facts where the spec cut the closing essay entirely, and
  the day's calendar as its own timeline. Thin because it carries no age on anything, which is the
  half the current format already gets right. The sample folds all three in.
- built and released 2026-08-17 as 1.14.0, at the user's instruction to skip the ledger because
  another session held the one open-run slot. `commands/sweep.md` went 325 to 444 lines in three
  edits: step 4 gained the eight-field item and the seven-rule urgency ladder, step 5's three flat
  tags became the `age`, `state` and `verified` fields, and step 6's three-line render became a
  ten-block page order with five conditional sections. All three sample defects are fixed in it —
  `decaying` widened rather than an eighth band added, `Dated` widened to include overdue, and a
  date inside a description made to count.
- proved 2026-08-17 by a live `--dry-run` over a 1h58m window, executed from the repo tree rather
  than through `/polaris:sweep`, because the installed cache was still 1.13.0 and would have
  rendered the old format. All six sources read. The render is in the scratchpad at
  `sweep-dryrun-2026-08-17-evening.md`, prose exit 0, and every printed count equals its rendered
  rows, checked by script rather than by eye.
- next: nothing owed. Two things to watch on the next real run. A 12:34 local start reads as the
  evening block, so a midday sweep runs the OKR interview rather than the pace read, which is
  inherited behaviour and not new. And `Start here` picked a 13-day-overdue backlog line over the
  window's most interesting finding, which is the rank working as specified and worth confirming is
  what you want after a week of it.
- files: commands/sweep.md, scripts/sweep-window.sh, scripts/okr-pace.sh,
  .polaris/specs/sweep-briefing-format.md, CHANGELOG.md,
  .polaris/releases/2026-08-17-v1.14.0.md
- touched: 2026-08-17 (built, dry-run proved, released as 1.14.0)

## token-efficiency — make Polaris affordable at the limit, not just correct

- domain: feature
- status: active, on the build phase
- state: Opened 2026-08-03 after the user reported that one default `/polaris:review` costs about
  half a session limit. The measured cause: `review.js` at its `high` default dispatches 7 reviewers
  at `effort: 'high'` plus up to 7 verifiers, and `rules/model-floor.json` floors 12 of those 14 at
  opus. The Claude Code docs then corrected the cost model: a subagent "builds its own cache,
  starting with no cache hits on its first call" and uses the five-minute TTL even on a subscription,
  so agent count dominates the bill rather than model tier, and a mixed-tier fan-out is
  cache-neutral. `.polaris/specs/token-efficiency-briefing.md` holds the research, 
  `check-patterns.sh prose` exit 0. Two shipped this session, ahead of the spec: the clarity veto is
  deleted from the tree and patched out of the live `1.10.0` cache (backup beside it), and the suite
  is at 184 assertions, exit 0.
  Both gated phases are now behind it. `spec` is recorded and approved: 421 lines, 36 acceptance
  criteria, requirements ranked to lead with the measured 67% long-context term ahead of the 6%
  review term. `design` is recorded and approved: `.polaris/plans/token-efficiency.md`, 827 lines,
  13 tasks across 17 steps, tasks 1-6 at full code detail and 7-12 held at interface resolution
  until phase-1 measurements exist. Two amendments came from the user during design. The `/clear`
  gate was widened from an approved predecessor to a recorded one plus `run-state.sh assert`, after
  the approval reading was found to skip 41 of 52 catalog boundaries including `feature`'s
  `build` to `ship`. And task 5a was added to measure whether `SessionStart`'s `initialUserMessage`
  lets the resume skip the prompt, because a hook cannot run `/clear` itself and the docs do not
  settle what that field does.
  Phase-1 build is in flight. Tasks 1-4 are done and the suite is 184 to 200 assertions, exit 0:
  the recovery line in `enhance-prompt` now names the last recorded artifact, `advance-flow` carries
  the gated `/clear` recommendation, and the injected payload is trimmed. The tester mutation-proved
  the new assertions in a sandbox, narrowing the gate back to requiring approval to confirm the
  regression fixture bites. Measured payload: 44923 bytes before, 35310 after, on a
  `.polaris/work/streams.md` that grew to 12059 bytes mid-run.
  The build workflow did not finish cleanly. Task 4's agent died after about 23 minutes without
  recording a result, and the workflow retried it. The retry had none of its predecessor's context,
  and it silently replaced `${recorded}` in `hooks/enhance-prompt` with the word "something",
  defeating the requirement that the recovery line name the artifact. The suite went red at 199 and
  the failing assertion was the one the first agent had written, which is the only reason it was
  caught. The workflow was stopped by hand, the line was restored, and the suite is green again at
  200. The review lenses and the report never ran under that workflow and were relaunched on their
  own.
  A 2026-08-09 audit re-measured the payload and named the one term nothing bounds. The injected
  slice of this file, across its last six commits, went 849 to 1197 to 2142 to 2739 to 6476 to 12553
  bytes: monotonic, fifteenfold in five commits, and now larger than `rules/core.md` at 10135. The
  `## Done` exclusion bounds nothing, because the active section is what grows. Session payload is
  about 33KB and a `/clear` re-pays all of it, so the clear's saving shrinks as this file grows.
  Subagent injection is a smaller separate term: `hooks/inject-standard` is about 1.9KB per subagent,
  paid 28 times by a `critical` review at its ceiling. The audit also confirmed the tree is one
  release ahead of what runs: the veto removal, the payload trim, and the tests asserting both are
  all uncommitted, so `HEAD` and the marketplace clone at `067a682` still carry the veto.
  Phase 2 landed on 2026-08-09, minus the one task that needed a measurement. `scripts/review-level.sh`
  holds the R3 table as the only copy of those thresholds and survives binary counts, both rename
  forms, spaces in paths, and malformed input. `workflows/review.js` gained the evidence pack, built
  once before the fan-out, capped at 1500 diff lines with the drop count stated and the diff framed as
  untrusted data; the confirm narrowing at `high`, where a `medium` whose fix is 80 characters or less
  returns unconfirmed naming its fix size while `high` severity is never narrowed; and a no-dispatch
  path for the empty level the script prints when nothing changed. The suite is 222 to 237, exit 0,
  and the pack and the filter are run as real code rather than grepped.
  Task 9's probe ran the same day and answered its open question against the plan's first branch. A
  workflow `agent()` dispatch reaches no hook: the probe dispatched `polaris:reviewer` at `haiku`,
  four tiers under its floor, and it ran unrefused. A main-loop `Agent` dispatch does reach
  `guard-phase`, from the `1.11.0` cache, carrying `description`, `prompt`, `subagent_type`, and
  `model`, with the session's effort at top level outside `tool_input`. Two consequences: the review
  level has to move through a file under `.polaris/runs/<slug>/`, which is a wording amendment to
  AC26 through AC28; and the effort floor already built for R4 reads `.tool_input.effort`, which
  nothing populates, so that hook governs nothing. Both are written up in the report's section 3a.
  It is all committed and released as of 2026-08-09. `0d8c73f feat: make a long session affordable
  and cap what every clear re-pays` carries 22 files: the veto deletion from `hooks/hooks.json`, the
  `/clear` recommendation in `advance-flow`, the artifact-naming recovery line in `enhance-prompt`,
  the trimmed `session-start` payload at 59358 to 46380 bytes, `scripts/tracker-slice.sh` at a
  10240-byte newest-first ceiling, `run-state.sh amend`, `scripts/review-level.sh`,
  `rules/effort-floor.json` with a named effort at every dispatch in all three workflows, and the
  `review.js` evidence pack and confirm narrowing. `8a36711 chore: release 1.13.0` dates it in
  `CHANGELOG.md` and bumps both manifests. The suite is 268 `ok` lines, exit 0. `1.13.0` is the
  newest installed cache, so the tree and what runs finally agree and the hand-patched `.bak` files
  beside `1.10.0` and `1.11.0` are dead weight.
- next: three of the audit's six approved fixes did not land in `0d8c73f` and are still owed. The
  `advance-flow` marker key still reads `${session}-${slug}-${phase}-${status:-open}` at line 70, so
  every phase still blocks twice. `rules/core.md` has no information test. `commands/enhance.md` line
  14 still returns the prompt to the user unchanged. The `.claude/` gitignore is moot, the directory
  is gone. Then three build tasks are left and each waits on something this session cannot do alone.
  Task 5a
  measures whether `SessionStart`'s `initialUserMessage` lets a resume skip the prompt, which needs a
  live `/clear` only the user can perform. Task 9 moves the review level through a file under
  `.polaris/runs/<slug>/`, and its spec amendment to AC26 through AC28 is owed first. Task 12 needs
  real review runs to report a per-level agent count and tier, and it is the expensive one. The
  `build` phase is deliberately not recorded in the ledger while those three are open. Separately,
  decide what to do about an effort floor no dispatch can reach: `guard-phase` reads
  `.tool_input.effort`, a workflow `agent()` fires no hook at all, and a main-loop `Agent` dispatch
  carries no effort field, so the per-level table in each workflow is the only thing governing
  effort today. That limit is stated in the 1.13.0 changelog rather than hidden.
  Two design findings are carried and resolved in the plan: `guard-phase` sees only
  `subagent_type`/`agent_type`/`subagentType`/`model` on stdin so the review level is not
  determinable there (task 9 measured it, and the answer is the plan's second branch), and
  `review.js` cannot shell out, so the caller passes `args.level`.
  Owed next, in this order: amend the spec so AC26 through AC28 read as a run whose review level is
  recorded rather than a dispatch payload carrying it, then build task 9 against a file under
  `.polaris/runs/<slug>/`. Decide separately what to do about an effort floor no dispatch can reach.
  Task 12, the report's per-level agent count and tier, still needs real review runs and is the
  expensive one left.
- files: workflows/review.js, scripts/review-level.sh, scripts/tracker-slice.sh,
  rules/model-floor.json, rules/effort-floor.json, rules/model-routing.md, hooks/guard-phase,
  hooks/hooks.json, hooks/enhance-prompt, tests/run-tests.sh, CLAUDE.md,
  .polaris/specs/token-efficiency-briefing.md, .polaris/specs/token-efficiency.md,
  .polaris/plans/token-efficiency.md, .polaris/reports/2026-08-03-token-efficiency.md
- raised 2026-08-09, not yet specced: whether the workflows optimize reasoning effort and not only
  model tier. The user named effort as a main reason usage shoots up. `workflows/review.js` already
  sets effort per level in its `LEVELS` table, low at `low` through high at `high` and `critical`,
  while `rules/model-floor.json` governs tier. Whether `build.js` and `verify.js` set effort at all,
  and whether the floor should carry an effort column beside the tier, is open.
- touched: 2026-08-09 (everything built so far committed as `0d8c73f` and released as 1.13.0, suite
  268 exit 0; three of the six audit fixes found missing from that commit)
- was a live problem, closed on 2026-08-09: the removed clarity veto kept firing for three more prompts
  because hooks load into a session at start, so a cache patch needs `/reload-plugins` or a restart
  before it takes effect. It then came back when the installed plugin moved to `1.11.0`, which was
  cut from the commit before the deletion. Both `1.10.0` and `1.11.0` are patched by hand with a
  `.bak` beside each. Every version bump restored it until the repo's `hooks/hooks.json` shipped,
  which it did in 1.13.0. It fired again on 2026-08-09, stopping a real prompt with
  "What files or errors should I fix?", and the user got through only by prefixing the resend with
  "dont veto the following prompt". Two further reasons it cannot be lived with: it is a
  `type: "prompt"` hook, so it runs no shell and reads no config, which means `routing: false` does
  not disable it; and its own prompt makes ending the turn the delivery mechanism, so the rewrite it
  returns is the consolation prize for being blocked rather than an enhancement.
- decided, do not reopen: the model floor follows the review level (sonnet at low and mid, opus at
  high, opus everywhere at critical), and the level is chosen from the diff with the explicit
  argument kept as an override.

## oneonone-prep — prepare the user for a manager 1:1 from state Polaris already holds

- domain: feature
- status: active, on the ship phase, blocked on a human
- state: The `feature` run under `.polaris/runs/oneonone-prep/` has spec recorded and approved at
  2026-08-04T14:54:39Z: `.polaris/specs/oneonone-prep.md`, 87 acceptance criteria across 13
  requirement groups, sha `9188465e00fa`, `check-patterns.sh prose` exit 0. It picks a new
  `/oneonone` command with verbs `add`, bare, and `recap` over a `/sweep` lens. Design is in flight;
  `.polaris/plans/oneonone-prep.md` does not exist yet. The feature has a hand-built precedent that
  landed while the spec was being written: two sessions in the Sage project produced
  `~/.claude/polaris-memory/oneonone/agendas/2026-08-05-oneonone.md` (14.7 KB, frontmatter carrying
  variant, window, six sources and the Notion URL) and published it to Notion under Work OS → 1:1 →
  "1:1 — 2026-08-05". That is the format reference and the architect has read it. The five-section
  shape came from source material the user supplied: two Reddit threads on making 1:1s meaningful
  and a video transcript of a wins-first agenda. The mechanic worth building is that the report owns
  the meeting and sends the agenda a day ahead, and what defeats every template is forgetting
  between meetings what you meant to raise.
- built, 2026-08-09: design approved and recorded, then tasks 1 to 8 of 9 built and green.
  `scripts/sweep-window.sh` gained `--first-run-hours` clamped to the cap; `scripts/oneonone-join.sh`
  and `scripts/oneonone-inbox.sh` are new with two fixtures cut from a live calendar pull;
  `commands/oneonone.md` carries `add`, assemble and `recap`. The suite went 185 to 217 assertions,
  `check-commands.sh` and the prose check both exit 0. Four defects in the plan surfaced only against
  real data: jq's `fromdateiso8601` cannot parse the `+05:30` the calendar returns, `list_meetings`
  carries neither `created` nor `duration_minutes` so the self-instrumenting lag never accumulates,
  `cwd` is per tool call so project discovery had to collapse 73 directories to 7 repository roots,
  and two assertions were wrong (a four-recording fixture claimed against a single-resolution
  expectation, and `wc -l` padding on macOS).
- next: task 9 is the live run and is the only work left. It creates a Notion subpage, so it waits on
  the user. Nothing is committed and nothing is pushed; the ship phase waits on the same word. Four
  findings from the
  real artifact are with the architect and the plan has to answer them: the meeting slipped to
  2026-08-07 and ran as an untitled impromptu call, then the user wrote an `## Outcomes` section
  back into the same Notion page, so the loop is prepare → meet → recap rather than prepare → meet;
  the recap's `Not raised` list carries seven unreached items into the next meeting and no
  acceptance criterion covers carry-forward; AC 34's "the second run rewrites that one file"
  contradicts the user's instruction that removed content stay removed; and the generated draft
  credited the user with work they did not build. One cleanup is still owed: the orphan run ledger
  at `.polaris/runs/oneonone-prep/` inside the worktree.
- documented 2026-08-17 in `b4df35e`: `/oneonone` had shipped with `commands/oneonone.md` and two
  scripts and no doc named it, so an installed copy gave no way to discover it. `README.md` and the
  `CLAUDE.md` command table now carry it, `oneonone-inbox.sh` and `oneonone-join.sh` included.
- reshaped 2026-08-25 from the user's own 1:1 feedback, ahead of the live run. Two of the sections
  were wrong for what the meeting is for. `Wins` was being filled with delivery, and the user was told
  wins are the work nobody asked for, so the section now refuses a shipped ticket, a closed sprint or
  an asked-for PR outright and sends them to `Status grid`. A new `Product thinking` section sits
  second and answers the standing feedback that the user reasons about the technical problem and not
  the product one: every instance in the window where he did the second thing, uncapped, because the
  count is the point, and zero written as zero. The section list is ten rather than nine. Sourcing
  widened to match, on the user's instruction: step 4 now pulls Slack after Jira, reusing `/sweep`'s
  `sources.slack` block and the connectors-rule thread sequence at a ceiling of 8 channels and 20
  threads, because neither an outside-scope win nor a product argument leaves a commit. Step 6 went
  from one transcript to four, newest first, with only the newest driving `Open from last time` and
  the older three read for repeat feedback, tagged `raised · N meetings`. Suite exit 0, prose exit 0.
- files: .polaris/specs/oneonone-prep.md, .polaris/plans/oneonone-prep.md (not yet written),
  commands/oneonone.md, scripts/oneonone-inbox.sh, scripts/oneonone-join.sh
- touched: 2026-08-25 (Wins redefined, Product thinking added, Slack and four transcripts wired in;
  the live run and ship still wait on the user)
- decided, do not reopen: the work happens in the git worktree `.claude/worktrees/oneonone-prep` on
  branch `worktree-oneonone-prep`, at the user's request.
- found this session, worth a fix of its own: a worktree does not isolate a Polaris run. All four
  flow gates and `scripts/run-state.sh` resolve their paths from `CLAUDE_PROJECT_DIR`, and which
  checkout that names moved mid-session — a `"routing": false` written into the main checkout's
  config never took effect here, because the gates were reading the worktree copy.

## Done

- router-questions — an open question no longer opens a run. `conversation` admitted only a question
  whose second word was an auxiliary, so "what new feature can we introduce in polaris, or what
  feature can we fix" matched the `feature` row on the words "new feature" and seeded
  `.polaris/runs/feature-0907` with a spec phase. Three patterns went into the `conversation` row in
  `rules/patterns.json`: a wh-word followed anywhere by `(should|shall|can|could|would|do) (we|i|
  you)`, a sentence-initial `should we`, and `thoughts on|any ideas|what do you think`. The class
  order is untouched, because it is the policy and the research fixture "what do other teams use for
  feature flags" depends on it. Six question shapes and the no-seed case are asserted in
  `tests/run-tests.sh`, plus four fixtures in `tests/fixtures/routing-cases.txt`.
- what it leaves: the domain rows above `conversation` still win, so "what should we clean up next"
  routes to `cleanup` and seeds. Moving the row up would break the research fixture, so this is a
  known residual rather than an oversight.
- worktracker-snapshot — the `Asked:` line is the prompt the user typed. The source was the session
  transcripts under `~/.claude/projects`, which carry every user-role turn, so hook-injected
  context, tool results, and a workflow agent's own prompt arrived as the question: three snapshots
  in three days reconciled against text the user never wrote. It now reads `~/.claude/history.jsonl`,
  one record per typed prompt with `display`, `project`, and an epoch-ms `timestamp`, filtered by
  project and cutoff, with `POLARIS_HISTORY_FILE` overriding the path for the suite. Proven against
  the real file: the window since 2026-09-07T11:05:15Z came back as fifteen typed prompts and
  nothing else. Both copies of the script carry the fix; the suite asserts they stay identical and
  that neither reads `claude/projects` again.

- plugin-audit — held the whole plugin to the current Claude Code contract, and the whole triage list
  landed. Ten commits: `0b763de` delivered the standard and made five gates gate, `2203571` deleted
  the three dead ui skills and stopped the install spilling machine-wide, `9c763f4` split the
  working-life half into `plugins/polaris-work/`, `31b7197` connected the review level, kept the
  ledger, and added `usage-facts.sh`, `c1b1270` gave the router its `ship` and `continuation`
  classes and stopped repeating the menu, then `42a8d9a`, `4b01ab8` and `97f8af5` reconciled the
  docs and cut 1.16.0, and `dd6323d` plus `5fc428d` bounded the workflow fan-out and validated the
  usage-facts subcommand as 1.16.1. The run `see-entirelty-of-this` recorded `audit`, `triage`,
  `fix`, and `verify`, and is archived under `.polaris/runs/.done/`.
- what the audit's own fix left open: the router still places questions as work, which is the
  `router-questions` stream, and `usage-facts.sh` is wired to nothing that reads it. Triage item 18
  asked for `/catchup` and the review-level heuristic to read `~/.claude/usage.db`; the script
  exists and no command calls it.

- review-levels — gave `/polaris:review` four levels and bounded its fan-out, shipped as 1.11.0
  (3c2bc1b, 067a682). `workflows/review.js` carries the `LEVELS` table, the coerced-string level
  resolution, and the batched per-dimension Confirm stage; ceilings are 2, 8, 14, and 28 agents. The
  user has since called the hand-passed level "kinda patch fix", because `high` stays the default and
  so the expensive path stays the common one. The `token-efficiency` stream is the follow-up that
  chooses the level automatically.
- open question this left, for a human: `.polaris/plans/review-levels.md` uses `- [ ]` checkboxes as
  its resume ledger, but the plan artifact's sha256 is locked in as the design phase's evidence in
  `.polaris/runs/review-levels/state.json`; ticking a box after design is recorded invalidates that
  phase under the run-ledger rule. Decide whether the plan template should stop carrying checkboxes
  once a plan is hash-locked, or whether the ledger should hash phases instead of whole files.

- gaps — closed the top three plan-vs-code gaps from the 2026-07-15 research report, and the three
  changes are committed (873d34c, 793a357). The master plan §3 no longer claims all-built and §3.4
  lists what is designed but unbuilt. The work tracker auto-maintains from a session-start
  reconcile, and /flow writes run history to .polaris/runs/. The remaining §3.4 items (monitors,
  cost meter, /schedule, connectors, embeddings RAG) stay deferred, low value at one user until a
  felt need.
- The revamp into an all-in-one project OS: M1 quality foundation, M2 handoff/audit docs, M3 fleet +
  routing + guardrails, M4 orchestration cycle + standalone modes, M5 prompt-enhance + dynamic
  synthesis, the work-tracker MVP, subsystem E file memory, the diagnostic modes, and the daily
  journal. Shipped across releases up to v1.2.1; each has a spec and plan in docs/.
