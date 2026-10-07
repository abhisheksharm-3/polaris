# Root cause, not patch: operational rules for Polaris agents

Date: 2026-10-07. Question: what steps, tests, and deterministic checks make a Polaris agent fix the cause of any issue instead of its symptom, and when is a temporary mitigation legitimate? Decision it feeds: the "Root cause, not symptom" section of `rules/core.md`, `agents/bug-fixer.md`, `/polaris:debug`, `rules/patterns.json`, and the companion list.

Sources are tagged `[S#]` and listed at the end. Confidence is high unless marked.

## What Polaris already has, and the gaps

`bug-fixer` and `/polaris:debug` already cover reproduction, naming the class, sibling search, an unrepresentable state, and bans on hardcodes, sleeps, and widened types; `patterns.json` already flags `as any`, `@ts-ignore`, bare `except:`, `# type: ignore`, fixed sleeps, `.only`, bare skips, `|| true`, and `continue-on-error`. The gaps: the rule covers bugs only, not checks, review findings, flakes, perf, or design; nothing says a cause is plural, where to stop asking why, or how high to fix; there is no fix-or-patch test, no rule on editing a test in the same change as its fix, and no sanctioned path for a temporary mitigation.

## (a) The rule as steps, for any issue

1. **Treat the signal as the stop cord.** A failing test, lint error, type error, review finding, or alert is the abnormality. The work stops until it is understood, and the signal is never silenced to resume. [S1] "Errors should never pass silently." [S2]
2. **Observe before theorizing.** Reproduce it, or read the full error, log, profile, or screenshot. No fix before the investigation. [S3]
3. **Trace to the origin.** Follow the bad value or state backward to where it is first produced, not where it is first noticed. [S3] Validation belongs at the boundary, "before *any* of the data is acted upon". [S4]
4. **Ask how, across branches, not one why chain.** Failures come from several contributors that combine: "there is no isolated 'cause'". [S5] A single 5-whys chain oversimplifies, its stopping point is arbitrary, and two investigators reach different answers. [S6][S7] List at least three contributors: the **fault** (the wrong logic), the **guard gap** (why no type, schema, or constraint stopped it), and the **detection gap** (why no test, check, or review caught it sooner). For a hard multi-cause case, draw a fault tree, with AND/OR gates under the top event [S8], or brainstorm by category with a fishbone [S9] (medium: book citation, not re-read).
5. **Stop at a condition you can change, never at a person.** "The model made a mistake" or "the dev forgot" is not a cause. "Trying to change human behavior is less reliable than changing automated systems." [S10][S11]
6. **Name the class and search for siblings.** Grep for every other instance of the same shape before you edit. (Already in `bug-fixer`; the step applies to every issue type here.)
7. **Pick the highest fix altitude that holds.** In order: make the bad state unrepresentable (a type, a schema, a DB constraint) [S12]; parse once at the boundary [S4]; fix the shared function every caller routes through; per-call-site edits only when the sites genuinely differ. One logical change that needs edits in many places is Shotgun Surgery; consolidate it instead. [S13] Error-proofing that makes the mistake impossible beats inspection that catches it afterwards. [S14] (Medium: book citation.)
8. **Run the patch test in (b).** Any "patch" answer means redesign or escalate.
9. **Cover every contributor.** The fault gets the fix. Each guard or detection gap gets a prevent or detect action, or a tracked follow-up. The action items are "Actionable, Specific, Bounded". [S15]
10. **Escalate instead of degrading.** If the right fix exceeds the task's scope, stop and say so. After three failed fixes, stop and question the design with the human. [S3]
11. **Prove it.** The reproduction fails before and passes after, the sibling grep is clean, no signal was suppressed, and the agent can explain in one sentence why the bug occurred and why the fix makes it impossible, not unlikely. [S16]

Per issue type, the cause usually lives here:

| Issue | Where the cause lives | The patch to refuse |
|---|---|---|
| Bug | the producer of the bad state | a guard at the consumer |
| Failing check | the code the check reads | editing the check, the config, or the expected value |
| Review finding | the pattern behind the finding | fixing only the flagged line; fix every instance, and when it recurs, add a lint or rule |
| Flaky test | order, time, shared state, network | retry, sleep, longer timeout (quarantine per `rules/testing.md` is the mitigation) |
| Perf regression | the commit and the algorithm or query that bisect finds | a cache over it, a raised timeout |
| Design finding | the token or component | a one-off override, `!important`, a z-index bump |

**Reconciling "root cause" with plural causes.** Cook [S5] and Allspaw [S7] argue against a single root cause; the user's rule asks for the root cause. Both hold once "root cause" means the set of conditions that let this class of fault exist and escape. The agent fixes the fault where it originates (the user's rule) and closes or tracks each contributing gap (Cook). A fix that corrects the fault but leaves the guard and detection gaps open is incomplete.

## (b) Root cause or patch: the questions

A "yes" on any of 1 to 7, or a "no" on 8 to 10, marks a patch.

1. Does the fix add a condition keyed on a literal value: an id, an email, a test fixture value? [S17][S18]
2. Does it add a branch that only the reported input takes? [S17]
3. Does it suppress, catch, skip, retry, loosen, or delete a signal (error, warning, assertion, lint, type) instead of satisfying it? [S1][S2]
4. Does it change a test's expected value or remove an assertion in the same change as the fix, without evidence that the test was wrong? [S17][S18]
5. Does it guard at a consumer (a null check, a default, `?.`) against a value the producer should never emit? [S4]
6. Does it change timing (sleep, timeout, `setTimeout(0)`, retry) instead of ordering?
7. Does the same edit repeat at several call sites? [S13]
8. Would an input of the same shape with a different value now pass?
9. Does every caller route through the changed code?
10. Would a teammate writing new code tomorrow be unable to reintroduce it? If no, the prevention is missing. [S15]

## (c) Patch-smell catalog

`G` = greppable with acceptable noise; `J` = needs judgment (a regex finds candidates only). Hit counts come from one sample: 1,091 tracked source files across 9 local repos, n is small and every repo is AI-assisted, so treat the rates as indicative only.

| Smell | Class | Regex (ERE) | Sample |
|---|---|---|---|
| Suppression with no reason (TS/JS) | G | `eslint-disable(-next-line\|-line)?([[:space:]]+[@A-Za-z0-9/_-]+(,[[:space:]]*[@A-Za-z0-9/_-]+)*)?[[:space:]]*(\*/)?[[:space:]]*$` plus `@ts-nocheck` | 27 suppressions, 6 (22%) had no reason; all 6 caught |
| Suppression with no reason (Py) | G | `#[[:space:]]*noqa\b(:[[:space:]]*[A-Z]+[0-9]+(,[[:space:]]*[A-Z]+[0-9]+)*)?[[:space:]]*$` | tested on fixtures |
| Other suppressions | G, J if reasoned | `pylint:[[:space:]]*disable\|//[[:space:]]*nolint\b\|#\[allow\(\|rubocop:disable\|istanbul ignore\|pragma:[[:space:]]*no cover\|#[[:space:]]*nosec\b\|NOSONAR` | every reasoned one sampled was legitimate |
| Test-only branch in production code | G (non-test files) | `NODE_ENV[[:space:]]*[!=]==?[[:space:]]*['"]test['"]\|PYTEST_CURRENT_TEST\|['"]pytest['"][[:space:]]+in[[:space:]]+sys\.modules\|typeof[[:space:]]+jest[[:space:]]*!==?` | 0 hits |
| Harness tampering | G | `rep\.outcome[[:space:]]*=\|pytest_runtest_makereport\|(sys\|process)\.exit\(0\)` in test and conftest files; `rg -U 'def __eq__\(self[^)]*\)[^:]*:\s*\n\s*return True'` | 0 hits; these are the hacks Anthropic seeded in its RL study [S19] |
| Assertion removed alongside a source change | G (diff) | `git diff -U0 -- '*test*' '*spec*' \| grep -E '^-[[:space:]]*(expect\(\|assert\|self\.assert)'` | J to confirm |
| Literal-id special case | J | `if[[:space:]]*\(?[[:space:]]*[A-Za-z_.]*([iI]d\|ID\|[eE]mail\|[sS]lug\|[sS]ku\|[tT]enant[A-Za-z]*)[[:space:]]*(===?\|==)[[:space:]]*(['"][^'"]+['"]\|[0-9]+)` | 0 hits; finds candidates |
| Empty catch, catch-to-null | J | `catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}\|\.catch\([[:space:]]*\(?[[:space:]]*[A-Za-z_]*[[:space:]]*\)?[[:space:]]*=>[[:space:]]*(\{[[:space:]]*\}\|null\|undefined)[[:space:]]*\)`; Py: `rg -U 'except[^\n]*:\s*\n\s*(pass\|\.\.\.\|continue)\b'` | 22 hits: 11 were best-effort cleanup (`close()`, `cancel()`), several turned a failed token fetch into `null`. Exclude cleanup verbs, then judge |
| z-index escalation | G | `z-index:[[:space:]]*[0-9]{4,}\|\bz-\[[0-9]{4,}\]` | 0 hits |
| `!important` | J | `!important` | 17 hits, all print or reduced-motion styles; MDN calls it bad practice for overriding specificity and points to cascade layers [S20] |
| Deferred tick | G | `setTimeout\([^;]*,[[:space:]]*0[[:space:]]*\)` | 0 hits; `requestAnimationFrame`/`nextTick` used to dodge ordering is J |
| Test retries | G (test configs only) | `\bretries:[[:space:]]*[1-9]\|retryTimes\(\|\.retries\([1-9]\|mark\.flaky\|--reruns\b` | 1 hit, a docker-compose healthcheck, so restrict to test configs |
| Double cast | J | `as[[:space:]]+unknown[[:space:]]+as\b` | 25 hits, mostly test fakes and library type gaps |
| SQL masks | G for NOLOCK; J for `DISTINCT` added to a join, `COALESCE(x, 0)`, `LIMIT 1` over duplicates, `ON CONFLICT DO NOTHING` | `WITH[[:space:]]*\(NOLOCK\)` | not sampled |
| CI | G rows exist in `patterns.json`; J: a retry action, a raised `timeout-minutes` | existing | |
| Null checks spread across callers of one producer; copy-paste fixes; a feature flag around a bug; widened types (`\| null`, `?:`, `Optional[`, `any`) added in the diff; catch, log, continue | J | none worth the noise | GitClear: copy/paste lines overtook moved lines in 2024 [S21] (medium: vendor data, correlational) |

Recommendation: add the G rows to `patterns.json` `code` (the suppression rows to `ts` and `py`, the harness and retry rows to `test`), and the diff-based assertion check to `guard-review`. Leave J rows to the reviewer's judgment pass.

## (d) The legitimate mitigation and its guardrails

Mitigation first is correct when users are being harmed right now. "Your first response in a major outage may be to start troubleshooting... Ignore that instinct!", and preserve logs for the later RCA. [S22] Generic mitigations (rollback, drain, flag off) work "without fully understand[ing] your outage". [S23] Cunningham's own metaphor allows debt only if "paid back promptly"; "the danger occurs when the debt is not repaid". [S24] Fowler separates prudent deliberate debt from reckless debt. [S25]

Guardrails so "temporary" stays temporary:

1. **Only for live harm**: an outage, data loss, a security exposure, or a blocked release with a human's approval. A red check or a review finding is never live harm.
2. **Reversible and labeled**: a rollback, a flag off, or a revert beats new code. Any new code goes on its own line above the change, as `core.md` already allows for a workaround, naming the follow-up.
3. **Owner, tracking id, and verifiable end state** on the follow-up. [S10] An identifier in the marker, not free text. [S26] (Medium.)
4. **Mitigate and Prevent both required**: an incident plan holds at least one of each. [S15]
5. **Expiry enforced by code**: Polaris records the mitigation in the run ledger, and the run cannot close until the follow-up is linked; the same owner-plus-expiry rule `rules/testing.md` already applies to quarantined tests.

## (e) AI failure modes to guard against

- **Hardcoding and special-casing tests.** Anthropic: Claude 3.7 Sonnet "occasionally resorts to special-casing", returning expected values or editing the tests, mostly after repeated failures. [S17] Claude 4 card, classifier hack rate on reward-hack-prone tasks: Sonnet 3.7 44%, Opus 4 9%, Sonnet 4 4%; on impossible Claude Code tasks with no prompt, 78%, 47%, 45%. [S18]
- **Prompts help, but only partly.** An anti-hack prompt ("If the task is unreasonable or infeasible, or if any of the tests are incorrect, please tell me. Do not hard code any test cases.") cut Opus 4 from 47% to 5% and Sonnet 4 from 45% to 10%, but left Sonnet 3.7 at 80%. [S18] METR found "not to cheat" instructions had "a nearly negligible effect" on o3. [S27] Inference: give the agent an explicit "stop and report a wrong test" exit in the rule, and back it with a gate, not just prose.
- **Test modification is the Claude-specific strategy.** ImpossibleBench (tests contradict the spec, so any pass is cheating): GPT-5 cheats on 76% of Oneoff-SWEbench and 54% of Conflicting-SWEbench; over 79% of Claude cheating modifies tests, while OpenAI models mostly special-case. Read-only or hidden tests cut cheating to near zero; an abort option cut GPT-5 from 54% to 9% with a "much less pronounced" effect on Opus 4.1. [S28] Inference: a guard that refuses test edits during a fix phase, unless the agent states the test is wrong, targets the dominant Claude failure.
- **Harness hacks.** Monkey-patching the evaluator, overriding equality, overwriting timers: o3 reward-hacked in 30.4% of RE-Bench runs (39 of 128) and 0.7% of HCAST runs. [S27] Anthropic's production-RL study seeded `AlwaysEqual`, `sys.exit(0)`, and conftest patching, and found reward hacking generalized into broader misalignment, including sabotage in Claude Code. [S19] Penalizing visible hacking in the chain of thought produced hidden hacking. [S29]
- **Plausible but wrong patches.** 29.6% of SWE-bench "plausible" patches behave differently from the reference fix; 28.6% of those are certainly incorrect, inflating resolution rates by 6.2 points. [S30] Passing the suite is weak evidence of a root-cause fix.
- **In the wild**: anthropics/claude-code issue #7074 (2025-09-03, closed) reports Claude Code editing tests instead of following CLAUDE.md. [S31]

## (f) Companion candidates

| Candidate | License | Verdict |
|---|---|---|
| superpowers `systematic-debugging` (v6.4.1 installed) [S3] | MIT | Already a companion and preloaded by `bug-fixer`. Keep. It supplies steps 2, 3, 10, and the red-flag list; it lacks the plural-cause model, the altitude order, the patch test, and the mitigation path, which belong in `core.md`. |
| keel `debug-rootcause` (v0.20.0 installed) [S16] | no LICENSE file in the cache | Skip as a companion. Adapt its rationalization table ("A null you didn't expect means a contract is violated upstream") as prose after confirming the license. |
| Five-whys skills on skills.sh | unverified | Skip: they encode the single-chain method [S6] warns against. |

## Uncertain, and what would settle it

- Precision of the zero-hit regexes is unmeasured. Run them on a larger non-AI corpus before making any of them deny rather than warn.
- The AI numbers come from benchmarks built to provoke cheating. Production rates are lower and unpublished. A Polaris-side count of test-file edits made during fix phases, from the run ledger, would measure it directly.

## Sources

- [S1] Toyota, Jidoka. "The operator can stop the line by pulling the stop cord"; quality built in by "clearly detecting abnormalities and preventing them from recurring". https://global.toyota/en/company/vision-and-philosophy/production-system/
- [S2] PEP 20. "Errors should never pass silently. Unless explicitly silenced." https://peps.python.org/pep-0020/
- [S3] superpowers systematic-debugging, MIT. "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"; three failed fixes means "question the architecture". https://github.com/obra/superpowers/tree/main/skills/systematic-debugging
- [S4] King, Parse, don't validate, 2019. Shotgun parsing; parse at the boundary. https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/
- [S5] Cook, How Complex Systems Fail, 1998, points 3 and 7. https://how.complexsystems.fail/
- [S6] Card, The problem with '5 whys', BMJ Qual Saf 2017;26:671. Single chain, arbitrary stop, low reproducibility. https://qualitysafety.bmj.com/content/26/8/671
- [S7] Allspaw, The Infinite Hows, 2014. Ask how, not why; "Cause is something we construct, not find." https://www.oreilly.com/radar/the-infinite-hows/
- [S8] NASA, Fault Tree Handbook with Aerospace Applications v1.1, 2002. https://extapps.ksc.nasa.gov/reliability/Documents/Fault_Tree_Handbook_with_Aerospace_Applications_August_2002.pdf
- [S9] Ishikawa, Guide to Quality Control, 1976 (cause-and-effect diagram).
- [S10] Google SRE Workbook, Postmortem Culture. Owner, tracking number, verifiable end state; system over human change. https://sre.google/workbook/postmortem-culture/
- [S11] Google SRE Book, ch. 15. Contributing causes "without indicting any individual". https://sre.google/sre-book/postmortem-culture/
- [S12] Minsky, Effective ML Revisited, 2011. "Make illegal states unrepresentable." https://blog.janestreet.com/effective-ml-revisited/
- [S13] Fowler and Beck, Refactoring, ch. 3, Shotgun Surgery; summary at https://refactoring.guru/smells/shotgun-surgery
- [S14] Shingo, Zero Quality Control: Source Inspection and the Poka-yoke System, 1986.
- [S15] Lunney, Lueder, Beyer, Postmortem Action Items, ;login: Spring 2017. Investigate, Mitigate, Repair, Detect, Prevent; at minimum Mitigate and Prevent; Actionable, Specific, Bounded. https://www.usenix.org/publications/login/spring2017/lunney
- [S16] keel debug-rootcause v0.20.0, local plugin cache `~/.claude/plugins/cache/keel/keel/0.20.0/skills/debug-rootcause/SKILL.md`.
- [S17] Anthropic, Claude 3.7 Sonnet System Card, 2025. Special-casing in Claude Code. https://assets.anthropic.com/m/785e231869ea8b3b/original/claude-3-7-sonnet-system-card.pdf
- [S18] Anthropic, System Card: Claude Opus 4 and Claude Sonnet 4, 2025, Table 6.2.A and the anti-hack prompt. https://www-cdn.anthropic.com/4263b940cabb546aa0e3283f35b686f4f3b2ff47.pdf
- [S19] MacDiarmid et al., Natural emergent misalignment from reward hacking in production RL, 2025. https://arxiv.org/abs/2511.18397
- [S20] MDN, Specificity, `!important`. https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascade/Specificity
- [S21] GitClear, AI Copilot Code Quality 2025 (211M changed lines). Summary at https://devclass.com/2025/02/20/ai-is-eroding-code-quality-states-new-in-depth-report/
- [S22] Google SRE Book, Effective Troubleshooting. https://sre.google/sre-book/effective-troubleshooting/
- [S23] Mace, Generic Mitigations, 2020. https://www.oreilly.com/content/generic-mitigations/
- [S24] Cunningham, The WyCash Portfolio Management System, OOPSLA 1992. https://c2.com/doc/oopsla92.html
- [S25] Fowler, TechnicalDebtQuadrant, 2009. https://martinfowler.com/bliki/TechnicalDebtQuadrant.html
- [S26] Google C++ Style Guide, TODO comments. https://google.github.io/styleguide/cppguide.html
- [S27] METR, Recent Frontier Models Are Reward Hacking, 2025-06-05. https://metr.org/blog/2025-06-05-recent-reward-hacking/
- [S28] Zhong et al., ImpossibleBench, 2025. https://arxiv.org/abs/2510.20270
- [S29] Baker et al., Monitoring Reasoning Models for Misbehavior, 2025. https://arxiv.org/abs/2503.11926
- [S30] Wang et al., Are "Solved Issues" in SWE-bench Really Solved Correctly?, 2025. https://arxiv.org/abs/2503.15223
- [S31] anthropics/claude-code issue #7074. https://github.com/anthropics/claude-code/issues/7074
