# Polaris audit, 2026-09-05

Scope: every feature of the plugin at 1.15.0, against the Claude Code documentation current on
2026-09-05. Every finding below was verified by running a command or reading a fetched doc page.
The test suite passes: 277 assertions, 0 failures.

## The one-line verdict

The standard is never delivered. `hooks/session-start` emits 63KB into a 10,000-character cap, so
Claude receives a 2KB preview and a file path, and everything after it — the comment law included —
is on disk and out of context. On top of that, five of the gates do not gate, the router places 9%
of real prompts, and 17 of 27 agents have never run.

---

## 0. The standard does not reach the model (critical)

`hooks/session-start` builds 62,985 bytes and hands them to `additionalContext`. `context-window.md`:

> Output over 10,000 characters is saved to a file; Claude gets a preview and the file path instead.

This is not a projection. It happened at the start of the session that produced this report, and the
evidence is in that session's own directory:

    tool-results/hook-5847636f-...-additionalContext.txt   63,104 bytes
    transcript attachment: "Output too large (61.4KB) ... Preview (first 2KB)"

The preview cuts off inside `rules/core.md`. Everything below that line was written to a file the
model was told about and never read:

    ## Comments policy            <-- the comment law itself
    ## The clean code catalog
    ## Naming
    ## Fetch fresh docs before writing
    ## Skill resolution
    ## Karpathy mode rule
    # Polaris Craft Principles    <-- all of craft.md
    ... all of writing.md, model-routing.md, the load-on-demand block,
        the memory index, and the tracker slice

Every session, every `/clear`, every `/compact`. Polaris's own sibling hook knows the number:
`stop-capture:157` caps itself at 9,500 with the comment "hook output is capped at 10,000
characters". `tracker-slice.sh` caps at 10,240. The one injection that carries the standard has no
ceiling at all.

This reframes several findings below. The comment law has fired in 2 of ~904 sessions because the
comment law was not in context. The writing standard is enforced by a leaky commit hook rather than
by the rules text, because the rules text is not there.

It also corrects a claim I made before checking: **this does not cost 17,500 tokens per session.** It
costs a 2KB preview. The bug is correctness, not spend, and capping the memory index is worth doing
for a different reason than I first gave — it buys room under the 10,000-character budget for the
rules that should be resident.

Fix, in order: (1) cut the payload under 10,000 characters, which means the memory index and the
tracker slice stop being injected wholesale and the always-earned rules stay; (2) put the comment
law and the laziness ladder in the first 2,000 bytes, since truncation keeps the start of the file;
(3) assert the payload size in the test suite, which currently checks exit code, duration, and
content but never length.

---

## 1. Enforcement that does not enforce

### 1.1 The model floor is bypassed by any full model id (high)

`hooks/guard-phase` ranks a dispatch's model against `rules/model-floor.json`, whose `tiers` array
holds only the three aliases. A full model id ranks -1, and the `-ge 0` guard then skips the check.

    model=haiku                     -> DENIED
    model=sonnet                    -> DENIED
    model=opus                      -> ALLOWED
    model=claude-haiku-4-5-20251001 -> ALLOWED   <-- the floor is opus
    model=fable                     -> ALLOWED
    model=inherit                   -> ALLOWED

`sub-agents.md` states model accepts `sonnet|opus|haiku|fable|inherit` or a full id such as
`claude-opus-5`. The floor catches exactly the three spellings a caller is least likely to use.

Fix: normalise the id to its tier before ranking, and refuse an unrecognised value rather than
allowing it. `fable` passes an opus floor today while `scripts/check-agents.sh` fails the build on
`fable` and `inherit`, so the validator and the gate disagree about the same value.

### 1.1a The effort floor gates a field that does not exist (high)

`guard-phase:55` reads `.tool_input.effort`. The Agent tool takes `description`, `prompt`,
`subagent_type`, `model`, and `isolation`. There is no `effort` parameter, so the key never arrives
and the check never runs:

    {"tool_name":"Agent","tool_input":{"subagent_type":"polaris:reviewer","prompt":"x"}}
    -> ALLOWED, no effort key present

`rules/effort-floor.json` is 37 lines and four test assertions gating nothing. The tests pass because
they synthesise a payload carrying an `effort` key that a real dispatch never has, which is the
failure mode the plugin's own Rule 9 names: a test that cannot fail when the behaviour changes.

`effort` is real, but as **subagent frontmatter** (`low|medium|high|xhigh|max`) and as a workflow
`agent()` option. No agent in the fleet declares it. Fix: put `effort:` in the 27 frontmatters where
the floor intends it, delete the dispatch check, and have `check-agents.sh` enforce the floor at
validation time where it can actually see the value.

### 1.2 The comment law cannot block (high)

`hooks/guard-edit` runs on `PostToolUse` and emits `{"decision":"block"}` with exit 0. The hooks
reference is explicit:

> `PostToolUse` | Can block? **No** | Shows stderr to Claude; the tool already ran

CLAUDE.md claims "The comment law blocks, it does not warn ... the edit has to be fixed before the
turn continues." It does not. The two-strike counter, the block payload, and the escape hatch are
machinery around an event that cannot block.

Measured: the comment law has fired in **2 sessions**, against ~904 recorded in `usage.db`.

Fix: move the check to `PreToolUse` on `Edit|Write` with `permissionDecision: "deny"`. That blocks
for real, and it blocks before the bad file is written rather than after.

### 1.3 The commit and PR writing guard catches one quoting style (high)

`hooks/guard-commit-pr` extracts the message with a regex requiring a double-quoted `-m`. Same
banned words, different quoting:

    -m "double quoted"        -> BLOCKED
    -m 'single quoted'        -> ALLOWED
    -F /tmp/msg.txt           -> ALLOWED
    --file=/tmp/msg.txt       -> ALLOWED
    -m $'ansi-c quoted'       -> ALLOWED
    gh pr create --body-file  -> ALLOWED

A multi-paragraph message, which is what the standard asks for, is normally written with a heredoc
or `-F`. Those are exactly the paths that bypass the guard, so on real commits it rarely fires.

The same regex fires in the other direction: it scans any Bash command containing the string
`git commit`, so a test, a doc, or this audit report gets linted as if it were a commit message.
Writing this file with a heredoc was refused for quoting the test above.

Fix: read the staged message from `.git/COMMIT_EDITMSG` in a `PreToolUse` check rather than parsing
the command line. Do not match on quoting.

### 1.4 Three vendored skills are dead weight (high)

`skills/ui-new`, `skills/ui-polish`, `skills/ui-prototype` total 116,748 bytes and are copies of
companion skills Polaris already installs.

- `ui-prototype/SKILL.md` routes to 42 distinct `references/`, `assets/`, and `scripts/` paths.
  **0 of 42 exist.** `find skills -type f` returns seven SKILL.md files and nothing else.
- `ui-new/SKILL.md` runs `python3 skills/ui-ux-pro-max/scripts/search.py` twelve times. That
  directory does not exist.
- `ui-polish/SKILL.md` carries 10 unrendered `{{command_prefix}}` and `{{scripts_path}}`
  placeholders from its upstream, under a `<!-- Source: github.com/pbakaus/impeccable -->` header.
- Nothing under `agents/`, `commands/`, `rules/`, `tests/`, `hooks/`, `scripts/` references any of
  the three. `agents/ui.md` preloads the working upstreams instead.

Fix: delete all three. Retarget the four `ui-new` mentions in `skills/extract-design-system` at
`ui-ux-pro-max`.

---

## 2. Routing: the promise and the measurement

README: "You do not type any of them. Describe the work and `hooks/enhance-prompt` classifies it,
opens the run, and says which flow it chose."

Measured against `~/.claude/history.jsonl`, 800 real substantive prompts sampled at random and piped
through `scripts/route-prompt.sh`:

    unknown       726   (90.8%)
    feature        16
    bug            16
    fix            13
    conversation    6
    audit           6
    research        4
    foggy           4
    trivial         3
    qa              3
    security        2
    review          1

97 regexes over 18 classes place 9% of real developer prose. The `unknown` branch is therefore the
product, and it injects 895 bytes on **every prompt** where no run is open, not once per session:

    895 B x 40 turns = 35,800 B  ~9,900 tokens

for a menu of eighteen flows the model has already read, ending in "run /polaris:compose".

What it misses is not exotic. From the unmatched set:

    commit and push frontend, ensure you are on dev branch    -> no ship class exists
    raise a pr on frontend from login flow refactor to main   -> no ship class exists
    https://github.com/.../pull/1054                          -> a bare PR url is not review
    now come back to our previous work                        -> should be context
    also 404 should also be full bleed                        -> fix requires "fix the|this|that"
    squash and merge? or merge commit?                        -> should be conversation
    i dont udnersatnd, give proepr explaination on each issue  -> should be conversation

Two structural problems, not a pattern-tuning problem:

1. **There is no `ship` flow.** `agent:shipper` exists only as a phase inside other flows, so the
   most common developer instruction, "commit this and open a PR", routes nowhere.
2. **Most prompts are continuations, not new tasks.** The router assumes every prompt opens work.
   Since 91% never open a run, every follow-up in a session re-enters the unknown branch and
   re-pays the menu.

Fix: classify continuation against new task first and stay silent on a continuation; add a `ship`
class; emit the flow table once per session rather than once per prompt.

### 2.1 Run slugs are the first four words of the prompt

Real run directories Polaris created, taken from the block markers on this machine:

    also-lets-upgrade-to        anything-that-depends-on     can-we-not-see
    email-<address>-<domain>-com                          here-is-a-<credential>
    see-dev-proeprly-first      what-is-out-sprint           how-to-fix-this

The names carry no meaning and preserve typos, and a prompt beginning with an email address or a
credential turns that text into a directory name under `.polaris/runs/`, a path a project may
commit. Fix: name the run from the classified flow plus a date, or ask.

---

## 3. Cost

`hooks/session-start` injects **62,985 bytes, about 17,500 tokens**, on startup and on every
`/clear` and every `/compact`.

    rules/core.md            10,135 B   ~2,815 tok
    rules/craft.md            3,538 B     ~982 tok
    rules/writing.md          5,752 B   ~1,597 tok
    rules/model-routing.md    1,137 B     ~315 tok
    polaris-memory INDEX.md  33,475 B   ~9,298 tok   <-- 53% of the payload
    tracker slice (capped)    8,313 B   ~2,309 tok
    ------------------------------------------------
    total                    62,985 B  ~17,495 tok

The memory index is the largest single item and it has **no ceiling**. The work tracker got one,
`scripts/tracker-slice.sh`, after it grew to 17KB. The index is twice that and grows one line per
memory forever: 105 lines today across 103 entries. Release 0d8c73f capped the tracker and left the
bigger file alone.

Per section 0 none of this is billed, because none of it arrives. The reason to cap it is to get
under the 10,000-character budget so the rules that matter are resident. At the current split there
is no room: the index alone is more than three times the whole budget.

### 3.1 Installing Polaris plants 270 skills machine-wide

`scripts/ensure-companions.sh` clones `Mindrally/skills` into `~/.claude/skills/`, which is
user-global rather than plugin-scoped. That directory holds **270 skill directories** today.
`companions.json` names **43**. The other ~227 are never referenced by any agent, command, rule, or
test in the plugin, and a skill's description loads in every session of every project on the machine,
not only in projects that use Polaris.

Fix: install into the plugin's own skills path, or install only the 43 that are named, or make the
bulk opt-in the way `optionalCompanions` already is for shadcn.

---

## 4. The fleet is a quarter of its size

Counting real dispatches across every transcript on this machine:

    reviewer 16 sessions   verifier 7   product 5   tester 4   architect 4
    security-architect 2   researcher 2   tech-writer 1   data-modeler 1   code-cleanup 1

    never dispatched, once, ever (17 of 27):
    api-designer  audit-refactor  backend  bug-fixer  data-engineer  devops  e2e
    feature-builder  frontend-logic  infra  integrations  perf  prod-audit  shipper
    sre  ui  ux

Some are flow phase targets, so their zero reflects flows rarely completing rather than the agent
being useless. That is the same story as section 2: routing does not fire, so flows do not open, so
phase targets never dispatch. It still means the 27-agent fleet is, empirically, four agents and a
long tail.

`feature-builder` is Next.js-specific in a stack-agnostic fleet. `reviewer`, `verifier`,
`prod-audit`, and `audit-refactor` overlap heavily, as do `infra` with `devops` and `perf` with
`sre`.

---

## 5. Dead configuration

`workflows/review.js` reads `args.level` to pick 2, 8, 14, or 28 agents. `scripts/review-level.sh`
computes that level from a diff. **Nothing connects them.** Grepping the repo for a caller that runs
the script and passes the result finds only the workflow reading it, the script's own header
comment, and the specs describing the intended wiring. No command, no hook, no flow phase does it.

Every `workflow:review` run therefore takes the default, `high`: seven reviewers plus confirmation.
The four-level matrix shipped as 1.11.0, with 17KB of plan and spec behind it, is inert. The same
applies to `workflow:verify` and `workflow:build`, whose levels are read the same way.

Also unwired: `.polaris/runs/.composed-log` counts repeated composed shapes and prints a suggestion
to stderr at three occurrences, which nothing reads.

---

## 6. Packaging left on the table

`plugin.json` uses 11 keys. The current manifest schema supports these that Polaris omits, each
solving a problem Polaris currently solves by hand:

- **`${CLAUDE_PLUGIN_DATA}`**, a directory that survives plugin updates. Polaris writes markers into
  `~/.claude/skills/.polaris-mindrally-synced` and state into `~/.claude/polaris-memory/`. This is
  the documented answer to the stale-cache problem.
- **plugin-root `settings.json`** with `statusLine` and `subagentStatusLine`. Polaris ships
  `scripts/statusline.sh` and the README asks the user to wire it by hand.
- **`bin/`**, executables added to the Bash PATH. Polaris has 17 scripts invoked as
  `bash scripts/x.sh` in prose the model has to remember.
- **`channels`**, **`lspServers`**, **`experimental.monitors`**, plus `displayName`,
  `defaultEnabled`, `$schema`, `metadata`.
- `userConfig` supports `required`, `sensitive`, `min`/`max`, `multiple`. `maxLookbackHours` has a
  default and no bounds; `notionParentPageId` is not marked required.
- CI does not run `claude plugin validate --strict`, which is what catches a misspelled key.

`SessionStart` matches `startup|clear|compact`. The documented values include **`resume` and
`fork`**. A resumed or forked session gets no standard injected at all, and fork mode has been on by
default since week 33.

`SessionEnd` is a real event Polaris registers nothing on, and it is exactly where the abandoned run
pointer that CLAUDE.md complains about should be reaped.

### 6.1 The README's first instruction turns the product off

README:94 and :135 tell a new user to run `/init`. That is Claude Code's built-in, which writes
CLAUDE.md and no `.polaris/config.json`. Every hook that matters early-exits without that file:

    enhance-prompt:26   [ -f "$cfg" ] || exit 0
    guard-phase:17      [ -f ".../config.json" ] || exit 0
    guard-command:19    [ -f ".../config.json" ] || exit 0
    advance-flow:24     [ -f ".../config.json" ] || exit 0

So a user who follows the README verbatim gets a plugin with the routing, the flow engine, and all
three gates silently off, and nothing tells them. `/debug` collides the same way with the bundled
debug skill. Fix: write `/polaris:init` and `/polaris:debug` at those sites, and have `session-start`
say so when `.polaris/config.json` is missing.

---

## 7. Data on this machine that nothing reads

**`~/.claude/usage.db`** — 24MB SQLite, **904 sessions and 66,815 turn rows**. Each turn carries
`input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, tool_name, cwd,
is_subagent, agent_id`, plus an `agents` table with `agent_type` and `completed_at`. Zero Polaris
files reference it.

This is ground truth for everything Polaris currently estimates:

- The token-efficiency effort, 46KB of plan and 30KB of spec, is arithmetic over file sizes. This is
  the measurement.
- The model and effort floors are policy with no feedback. This says what a reviewer at opus and
  high effort actually cost against sonnet and medium, per agent type.
- Review levels are picked from diff-size heuristics. This could calibrate them on real spend.
- `/journal`, `/catchup`, and `/sweep` reconstruct activity by parsing 1.4GB of transcripts. Two SQL
  queries answer what was worked on, when, and for how much.
- `is_subagent` and `agent_id` answer the section 4 question directly and continuously.

Also unread: **`~/.claude/history.jsonl`** (15,771 real prompts with project and timestamp, the
corpus for measuring and fixing the router), **`~/.claude/stats-cache.json`** (per-day message,
session, and tool-call counts, which `/journal` rebuilds by hand), `file-history/`, `sessions/`.

Inside the repo, `.polaris/runs/*/state.json` records every phase, artifact hash, approval time and
amendment for every run ever opened. Nothing reads it back to learn which flows finish, which stall,
and where approvals sit — and worse, `run-state.sh:124` destroys it:

    rm -rf "${RUNS:?}/${slug}" "$OPEN"

`cmd_clear` deletes the ledger at the moment the run completes. The one dataset Polaris generates
about its own operation is erased exactly when it becomes a complete record. Fix: move the directory
to `.polaris/runs/.done/` instead of removing it, and let `/catchup` and the review-level heuristic
read it.

Two more the same shape: `journal/` holds 46 narrative days that `/catchup`, the morning briefing,
never opens; and `.polaris/reports/` is write-only, so `/research` never reads its own prior reports
before producing another.

---

## 8. Sediment

`.polaris/` holds 60 files and 700KB, including a 92KB plan and a 63KB spec for work already
shipped. `docs/plans` and `docs/specs` hold 25 more for delivered slices. `tests/run-tests.sh` is
1,247 lines with 218 assertions, of which 102 execute a hook or script and 16 only grep a markdown
file; that ratio is healthier than the file size suggests, so the suite is not the problem.

Marker directories in `TMPDIR` are never cleaned: 13 for `advance-flow`, 35 for `stop-capture`, plus
per-file counters, accumulating since 30 August. Three stale `.open-<session>` pointers and two
orphaned run directories sit in `.polaris/runs/`, and their slugs are permanently unusable because
`seed` refuses a slug whose directory exists.

---

## 9. One product or two

46% of the plugin's command prose is personal productivity rather than the software lifecycle.
`/sweep` (26,633 B) and `/oneonone` (23,662 B) are the two largest commands in the repo and together
are 40% of all command bytes. Both are about the owner's own job rather than about code.

A stranger installing "an all-in-one project operating system for Claude Code" gets a Notion
briefing pipeline, an OKR pace calculator, and a manager 1:1 agenda builder. Those are good tools.
They are a different product.
