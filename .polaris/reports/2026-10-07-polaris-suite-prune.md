# Polaris suite: split and prune, 2026-10-07

The test-engineer pass over `tests/run-tests.sh`, applying `rules/testing.md` sections 1, 2, 5 and 8.
Only `tests/` and this report changed. Nothing is committed.

## Before and after

| | Before | After |
|---|---|---|
| Files | 1 (`tests/run-tests.sh`, 2,100 lines) | runner (47 lines), `tests/lib.sh` (23), 14 suites; 2,139 lines in all |
| Assertions (`ok` lines on a green run) | 417 | 396 |
| Full run, wall time | 64.6 s at the start; 68.6 s back to back with the new suite | 47.8 s to 62.3 s across four runs |
| A change to `scripts/route-prompt.sh` | runs everything | runs 3 suites, about 21 s |
| A change to one suite file | runs everything | runs that suite |

Wall time on this machine swings by 15 s between identical runs, so treat the full-run numbers as
noisy. Pruning saved a second or two. The time win comes from selection, not deletion. One suite
dominates: `routing` takes 24 to 26 s of every full run. `scripts/route-prompt.sh` spawns one `grep`
per pattern, about 0.25 s a call, and the routing table calls it 77 times. That cost is in the router
itself, which runs on every user prompt, so the fix belongs in `scripts/route-prompt.sh` (one `awk` or
`jq` pass over the patterns), not in the test. It was out of scope here.

Slowest suites on the last full run: routing 25 s, run-ledger 4 s, patterns 4 s.

## The runner

`bash tests/run-tests.sh` runs every suite in `tests/suites/`, prints the same `ok:` and `FAIL:` lines
as before, then each suite's time, the count run, and the slowest three. It exits non-zero if any suite
does.

`bash tests/run-tests.sh --changed [base]` runs only the suites whose `# covers:` globs match a file in
`git diff --name-only <base>` or an untracked file. The base defaults to `origin/main`, else `HEAD`. A
change to `tests/lib.sh`, `tests/run-tests.sh`, or anything under `tests/fixtures/` runs every suite. A
suite always covers its own file. The rule lives next to each suite, not in a list in the runner.

## Suites and what they cover

| Suite | ok | covers |
|---|---|---|
| agents-and-floors | 19 | `agents/*.md commands/*.md scripts/check-agents.sh scripts/check-commands.sh hooks/* scripts/*.sh rules/model-floor.json rules/effort-floor.json` |
| commit-guard | 12 | `hooks/guard-commit-pr scripts/check-patterns.sh rules/patterns.json rules/writing.md` |
| design | 9 | `rules/flows.json rules/design-core.md hooks/inject-design hooks/inject-standard hooks/hooks.json agents/*.md companions.json workflows/build.js workflows/review.js` |
| edit-input-review-guards | 12 | `hooks/guard-input hooks/guard-edit hooks/guard-review hooks/hooks.json scripts/check-patterns.sh rules/patterns.json rules/core.md` |
| flow-gates | 40 | `hooks/guard-phase hooks/guard-command hooks/advance-flow hooks/session-end hooks/hooks.json scripts/run-state.sh scripts/review-level.sh rules/flows.json rules/model-floor.json` |
| patterns | 25 | `scripts/check-patterns.sh rules/patterns.json` |
| polaris-work | 76 | `plugins/polaris-work/* rules/connectors.md commands/catchup.md scripts/worktracker-snapshot.sh scripts/check-patterns.sh rules/patterns.json` |
| routing | 38 | `hooks/enhance-prompt scripts/route-prompt.sh scripts/run-state.sh rules/patterns.json rules/flows.json hooks/hooks.json` |
| run-ledger | 63 | `scripts/run-state.sh scripts/check-flows.sh scripts/inventory.sh hooks/guard-phase rules/flows.json agents/*.md commands/*.md workflows/*.js skills/*` |
| session-start | 29 | `hooks/session-start hooks/inject-standard scripts/tracker-slice.sh scripts/ensure-companions.sh scripts/check-patterns.sh scripts/route-prompt.sh rules/*.md rules/stacks/* rules/stack-map.json rules/patterns.json commands/*.md` |
| stop-capture | 38 | `hooks/stop-capture scripts/worktracker-snapshot.sh scripts/check-patterns.sh rules/patterns.json plugins/polaris-work/hooks/stop-capture commands/track.md .gitignore` |
| testing | 3 | `rules/testing-core.md hooks/inject-testing hooks/inject-standard hooks/hooks.json agents/*.md commands/*.md rules/*.md` |
| usage-facts | 5 | `scripts/usage-facts.sh` |
| workflows | 27 | `workflows/*.js scripts/review-level.sh agents/*.md` |

The covers lists came from what each hook and script actually reads (a grep of every hook and script
for `scripts/`, `rules/`, and `hooks/` paths), plus the files a suite inspects directly. A glob in a
`case` pattern matches across `/`, so `plugins/polaris-work/*` covers the whole plugin.

Each suite sources `tests/lib.sh`, owns and removes its temp directories, and runs alone with
`bash tests/suites/<name>.sh`. `lib.sh` holds `DIR`, `WORK`, `CHECK`, `fail`, `expect_exit`, and
`is_ctx`, which the design and testing suites share.

## Deleted assertions (21)

| # | Was in | Assertion | Rule |
|---|---|---|---|
| 1 | enhance-prompt | "enhance-prompt no longer judges its own prompt" (greps output for the phrase `judge whether this request`) | §5 change detector: it pins one retired phrase. The class it stood for, a model judging the prompt, is held by the kept "no prompt-type veto" assertion |
| 2 | guard-edit | "a denied write leaves nothing on disk" | §1.1 and §8: no nameable break. The test calls the hook alone with no harness, and the hook never writes the file, so this cannot fail |
| 3 | guard-edit | "guard-edit is no longer on PostToolUse" | §2 one-off pin. The real break, the hook not on PreToolUse where it can deny, is the kept assertion beside it |
| 4 | connectors | "connectors rule expands Slack threads" (greps `slack_read_thread` in a prose rule) | §5 change detector on prose wording |
| 5 | sweep-window | "first run stays 24h without the flag" | §5 duplicate of "first-run 24h fallback": same input and expectation, a different cap that does not bind |
| 6 | stop-capture | "stop-capture ignores a non-dated journal filename" | §8: could not fail. It read the SDLC hook's reason, and that hook stopped scanning the journal on 2026-09-07. The break is also implied by the kept "counts exactly the one pending day", since the non-dated file is a `status: facts` file and would make the count 2 |
| 7 | flows | the second `check-flows.sh` exit-0 run (old line 1277) | §5 exact duplicate of the first |
| 8 | route-prompt | "every routing class names a flow in the catalog" | §5 implied by the kept "every routing class has a flow and every flow a class" |
| 9 | effort floor | "a dispatch shaped like a real one carries no effort key to gate on" | §5 implied by the kept "a dispatch with no model is left to the agent's frontmatter": the same payload plus two inert fields |
| 10 | effort floor | "guard-phase no longer gates on a field that does not exist" (greps for `tool_input.effort`) | §2 one-off pin of dead code. Reading a field nobody sends changes no behavior |
| 11 | effort floor | "every agent declares the effort its floor requires" (frontmatter equals the floor) | §5: missing or below-floor effort is already failed by `check-agents.sh` on the real fleet, which the kept probe proves fails. The leftover strictness, failing an agent that raises its effort above the floor, is a change detector |
| 12 | advance-flow | "advance-flow names args.level for a workflow phase" | §5 implied by the kept "the level it names is one review.js accepts", whose regex contains it |
| 13 | router | "the router always answers" | §5 implied by the fixture table, where every row asserts an exact answer |
| 14 | router | "routed to conversation: how should i structure the ledger" | §5 exact duplicate of a `routing-cases.txt` row |
| 15 | router | "routed to conversation: any ideas for the router" | §5 exact duplicate of a `routing-cases.txt` row |
| 16 | router | "a research question still routes to research" | §5 exact duplicate of a `routing-cases.txt` row |
| 17 | router | "a question about what to build opens no run" | §5 implied: the same prompt is asserted to route to `conversation`, and the kept enhance-prompt block proves a conversation opens no run |
| 18 | router | "the run slug is built from the flow and the date" (greps one source line) | §5 change detector: any rewrite of that line fails it, safe or not. §2: the prompt-text slug was a one-off design choice |
| 19 | polaris-work | "polaris-work ships a config template" | §1.2: nothing executable reads `templates/config.default.json` (only the README names it), so no break follows from its absence |
| 20 | journal | "journal-facts no longer filters transcript prompts by blocklist" | §2 one-off pin of an absent string. The class, injected transcript text reported as a question, is held by the kept "the journal ignores a transcript turn the user never typed" |
| 21 | /standup | "polaris-work ships /standup" (file exists) | §5 implied by the kept grep on the same file, which fails if it is missing |

One assertion was rewritten rather than deleted. "review selects the design dimension for a ui diff"
hardcoded a copy of the `UI_FILE` regex, failed whenever the source regex changed for any reason, and
then tested the copy (§3.4 and §8: the expectation came from a copy, not from the code). It now reads
`UI_FILE` out of `workflows/review.js` and asserts on literal diffs: a diff with a `.tsx` file selects
design and a diff with only `.ts` and `.sql` files does not.

Some comments were updated to match: one above the effort probe, one above the conversation loop.

## Kept, with doubts

Each of these guards a real break, but it also fails on a deliberate change, or it is weaker than it
reads. Each one deserves a second look:

- `routing`: "the router is the only input hook" asserts exactly one `UserPromptSubmit` command hook. It
  catches the router being unwired, and it also fails on any deliberate second input hook.
- `polaris-work`: the three "cites the connectors rule" greps, and "/standup reads the facts extractor".
  These check that a doc references a file. They are kept because dropping the reference changes what
  the command does.
- `stop-capture`: "worktracker reads typed prompts, not transcripts" greps the script for
  `claude/projects`. It is the only guard, because the behavior tests run with the real `HOME` and
  have no fixture transcripts to leak.
- `stop-capture`: "the SDLC stop-capture leaves the journal to polaris-work", "tells the reconcile to
  stamp the cursor", "tells the session not to touch streams.md", and the two `/track` greps. These are
  wording checks on instructions to a model, kept because the instruction is the only thing preventing
  double asks or lost notes.
- `session-start`: the two "names the rules it stopped injecting" loops, "injects no rule body it cannot
  afford", and "every moved rule is loaded by a command". The cap assertion catches most of what the
  no-body greps catch, but not the smaller rule files, which fit under 9,000 bytes.
- `session-start`: "completes under 10s" is a wall-clock assertion, so §3.8 applies. The margin is wide,
  and startup cost is a real regression class, but it will flake on a starved CI runner first.
- `polaris-work`: "oneonone-inbox add names the file and the count" greps for `1`, which almost any
  output contains.
- `agents-and-floors`: "the refusal names the floor" (message wording), and "the effort levels span the
  documented range" (an exact list, which changes when the harness does).
- `workflows`: the source greps for `asked === ''`, `judgeBudget`, `reported unjudged`, `deferred`,
  `lensesFor`, and `confirm:${r.dimension}`. They guard fan-out ceilings and token cost, which are real
  costs, but a rename breaks them. The pack and level checks next to them run the real code; these
  could follow that pattern.
- `design`: the exact design-flow phase list, "the ui agent preloads frontend-design only", and "a ui
  slice in the build gets a ux critique". Each is a structure pin on a decision recorded in memory as
  deliberate.
- `polaris-work`: "journal second ask" may look like a repeat of "journal ask captured", but it comes
  from a second session in the fixture, so it was kept.

## Mutation proofs

For each suite, one bug-shaped break went into a file it covers. The suite then ran alone, and the file
was restored from a byte copy and checked with `cmp`.

| Suite | File | Break | Result |
|---|---|---|---|
| routing | `scripts/route-prompt.sh` | try classes in reverse order (`.routing \| reverse`) | exit 1; 4+ fixture rows misroute, such as "migrate to the new stripe api" want modernize got integration |
| commit-guard | `hooks/guard-commit-pr` | drop the fold that turns `$'...'` into a double-quoted string | exit 1; "ansi-c bypassed the writing guard" |
| polaris-work | `plugins/polaris-work/scripts/sweep-window.sh` | cap check `$gap > $cap` becomes `$gap > ($cap * 10)` | exit 1; "sweep-window cap" (start 2026-07-01, capped false) |
| session-start | `scripts/tracker-slice.sh` | `## Done` match loses its `\r?` | exit 1; "a CRLF tracker leaks its Done archive" |
| workflows | `scripts/review-level.sh` | judge only the old side of a rename | exit 1; "both sides of a rename are judged" and "a brace rename is expanded" (got low, wanted high) |

All five files are byte-identical to their pre-mutation copies.

`--changed` proof: in the working tree, `--changed HEAD` with a blank line added to
`scripts/route-prompt.sh` ran all 14 suites. That is correct under the rule, because the diff against
`HEAD` already holds `tests/run-tests.sh` and `tests/fixtures/routing-cases.txt`. In a scratch clone
(outside the project) with the new suites committed and the same blank line as the only change, it ran
exactly `agents-and-floors`, `routing`, and `session-start`. Session-start is selected because the hook
calls `route-prompt.sh`. In the same clone, a change to one suite file ran only that suite, a fixture
change ran all 14, and an empty diff ran none.

Flake check: three full runs gave the same assertion set each time.

## Open finding, not caused by this change

Two of the three full runs failed on "the session-start payload fits the hook cap": 9,009 chars against
the 9,000 threshold. `rules/core.md` and `hooks/session-start` changed in the working tree during this
pass, outside `tests/`. The original monolith fails the same way on the same tree. The assertion is
doing its job: the payload needs about 10 bytes trimmed, or the threshold needs a deliberate decision.
