# Audit triage: the ordered fix list

From `.polaris/reports/2026-09-05-plugin-audit.md` (sha `c9b11416`, approved 2026-09-07).

Ordering rule: T0 gates everything, because until the standard is resident every other enforcement
fix is applied to text the model cannot see. Inside each later tier the items are independent, so
they can be done in any order or in parallel.

---

## T0 — the standard has to arrive (blocks all of T1)

**1. Cut the SessionStart payload under 10,000 characters.**

The cap is not a budget to trim toward, it is a wall. `rules/core.md` is 10,135 B and busts it
alone, so this is not "cap the memory index" — the rules themselves have to split into resident and
on-demand.

`hooks/inject-standard` already proves the shape at 1,571 B. Proposed resident set:

    Comments policy (the comment law)        2,101 B
    The laziness ladder                      1,305 B
    Think before coding, verify after        1,406 B
    Philosophy                                 627 B
    Root cause / no workarounds / one file /
      no orphan / no duplicate                1,246 B
    Naming + clean-code catalog pointer         699 B
    ------------------------------------------------
    subtotal                                 7,384 B
    leaves ~2,600 B for the writing essentials, the on-demand paths, and pointers

Everything else becomes a path, which is the pattern `session-start:89-94` already uses for three
rules: `craft.md`, `writing.md` in full, `model-routing.md`, skill resolution, the docs protocol,
the Karpathy rule, the memory index, and the tracker slice.

Two ordering constraints inside this item: the comment law and the ladder go in the **first 2,000
bytes**, because truncation keeps the start of the file and the 2KB preview is the only thing
guaranteed to land. And the writing standard is already enforced deterministically by the gate and
the commit hook, so its prose is the cheapest thing to move out.

Files: `hooks/session-start:61-135`, `rules/core.md`, `tests/run-tests.sh`.

**2. Assert the payload size.** The suite checks exit code, duration, and content, never length. One
assertion that the payload is under 10,000 characters is what stops this recurring. Do it in the
same commit as item 1 or the fix has no guard.

---

## T1 — gates that do not gate

Each is independent. Each is small. All five are currently reported as working in prose.

**3. `guard-edit` → `PreToolUse` on `Edit|Write`, `permissionDecision: "deny"`.**
`PostToolUse` cannot block; the docs say so and the hook's own output proves it (exit 0, JSON
ignored). Moving it also makes it block *before* the bad file is written, which is strictly better
than the current after-the-fact design. Delete the two-strike counter — it exists to bound a block
that never happened. Files: `hooks/guard-edit`, `hooks/hooks.json:84-90`, `CLAUDE.md:132-134`.

**4. Model floor: normalise before ranking.** Map a full model id to its tier, and refuse an
unrecognised value instead of allowing it. Today `claude-haiku-4-5-*`, `fable`, and `inherit` all
pass an opus floor. Also reconcile with `check-agents.sh:18`, which fails the build on `fable` and
`inherit` — the validator and the gate currently disagree about the same value.
Files: `hooks/guard-phase:39-46`, `rules/model-floor.json`, `scripts/check-agents.sh`.

**5. Effort floor: move it to frontmatter and delete the dispatch check.** The Agent tool has no
`effort` parameter, so `guard-phase:55` reads a key that never arrives. `effort` is real as subagent
frontmatter (`low|medium|high|xhigh|max`) and no agent declares it. Put the floor's values in the 27
frontmatters, enforce them in `check-agents.sh` where the value is visible, and delete the runtime
check plus its four synthetic assertions.
Files: `hooks/guard-phase:50-68`, `rules/effort-floor.json`, `agents/*.md`, `tests/run-tests.sh`.

**6. `guard-commit-pr`: read the message, not the command line.** Five of six quoting forms bypass
it, including the heredoc and `-F` paths that a multi-paragraph message actually uses. Read
`.git/COMMIT_EDITMSG` in a `PreToolUse` check. This also fixes the false positive that refused to
let this audit be written by heredoc. Files: `hooks/guard-commit-pr`.

**7. `SessionStart` matcher: add `resume` and `fork`.** A resumed or forked session gets no context
at all, and fork mode is on by default. One-line change, and it widens the blast radius of item 1,
so do it after. Files: `hooks/hooks.json:5`.

---

## T2 — deletions and corrections, no design needed

**8. Delete `skills/ui-new`, `skills/ui-polish`, `skills/ui-prototype`.** 116,748 B; 0 of 42
referenced paths exist; `ui-new` calls a `search.py` that is not there; `ui-polish` still has 10
unrendered `{{...}}` placeholders. Nothing in the plugin references them and `agents/ui.md` already
preloads the working upstreams. Retarget the four `ui-new` mentions in
`skills/extract-design-system` at `ui-ux-pro-max`.

**9. Stop planting 270 skills machine-wide.** `ensure-companions.sh` clones into
`~/.claude/skills/`, which is user-global; 270 directories there against 43 named in
`companions.json`. Install only the named set, or make the bulk opt-in the way `optionalCompanions`
already is. Files: `scripts/ensure-companions.sh:38-56`.

**10. `/polaris:init` and `/polaris:debug` at all eleven sites.** `/init` is Claude Code's built-in
and writes no `.polaris/config.json`, and four hooks `exit 0` without that file — so a user
following the README gets the routing, the flow engine, and all three gates silently off. Add a line
to `session-start` that says so when the config is missing.
Files: `README.md:94,106,130,135,165`, `commands/route.md:38,64`, `commands/{handoff,incident,triage}.md`.

**11. Docs drift, one pass.** Three rules files say "Injected every session" and are not injected.
README names the wrong three as session-injected, promises three approval gates where the catalog
has two, calls `guard-edit` opt-in where the template enables it, lists 6 of 11 hooks and 30 of 32
commands. `docs/POLARIS_MASTER_PLAN.md` describes the pre-1.0 product in the present tense and names
three commands that do not exist.

---

## T3 — the router, which needs a design call

**12. Classify continuation against new task first.** 726 of 800 real prompts are `unknown`, and the
branch costs 895 B on every prompt because it re-fires on every follow-up. Staying silent on a
continuation is most of the win and needs no new patterns.

**13. Emit the flow table once per session, not once per prompt.**

**14. Add a `ship` class and flow.** `agent:shipper` exists only inside other flows, so "commit and
push, then raise a PR", one of the most common instructions there is, routes nowhere.

**15. Name runs from the flow and the date.** Slugs are the first four words of the prompt, so real
directories include `see-dev-proeprly-first` and `email-<address>-<domain>-com`. The second is a
privacy problem: prompt text becomes a committed path.

T3 is where the honest question sits. 97 regexes place 9% of real prose. Items 12-14 raise that
materially, but if the answer after them is still under half, the design to argue is whether
classification belongs in a regex table at all.

---

## T4 — wire what already exists

**16. Pass `args.level`.** Three workflows read it, nothing passes it, so every review runs at
`high` with seven reviewers. The `review` flow phase should run
`git diff --numstat | scripts/review-level.sh` and pass the result.

**17. Stop deleting the ledger.** `run-state.sh:124` does `rm -rf` on completion, erasing every
phase, hash, approval, and amendment at the moment the record is complete. Move it to
`.polaris/runs/.done/`.

**18. Read `~/.claude/usage.db`.** 904 sessions, 66,815 turns, per-turn token counts and `agent_id`.
It answers, continuously and for free, what the token-efficiency plan estimates by hand and what the
fleet question needs: which agents run, what each tier costs, which flows finish. Add one script and
let `/catchup` and the review-level heuristic read it. See also `history.jsonl` (15,771 real prompts,
the corpus for item 12) and `stats-cache.json`.

**19. Reap on `SessionEnd`.** A real event Polaris registers nothing on, and the right home for the
abandoned run pointer CLAUDE.md already complains about. Also clean the `TMPDIR` markers, 48 of them
accumulating since 30 August.

---

## T5 — the product question

**20. Split the personal half.** 46% of command prose is not about code. `/sweep` (26,633 B) and
`/oneonone` (23,662 B) are the two largest commands in the repo, and all three install-time
`userConfig` questions serve them. This is the decision that lets the SDLC half get small enough to
be the thing a stranger installs, and it is the one item here that is a judgment call rather than a
defect.

Do not start T5 before T0 through T2 land. The split is easier to argue once the plugin does what it
already claims.

---

## Sequencing summary

    T0  1-2    one commit, blocks everything    ~half a day
    T1  3-7    five independent commits         ~a day
    T2  8-11   deletions and text               ~half a day
    T3  12-15  needs a design call first        ~two days
    T4  16-19  wiring                           ~a day
    T5  20     a decision, then a migration     open

The `fix` phase of this run takes T0 and T1. T2 onward should be their own runs, because a single
`fix` phase covering twenty items is the same mistake as a review with no level.
