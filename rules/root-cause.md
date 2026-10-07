# Root cause, not patch

<!-- The full form of core.md's "Root cause, not symptom". It applies to every issue: a bug, a red -->
<!-- check, a review finding, a flaky test, a perf regression, a design finding. Sources are tagged -->
<!-- [S#] from .polaris/reports/2026-10-07-root-cause-research.md. -->

A patch makes the signal go away. A fix makes the class of fault impossible. A fix can take longer,
and that time is the expected cost, not a reason to patch: patches compound into code nobody can
change, and the same fault comes back somewhere else.

## The steps, for any issue

1. **The signal is the stop cord.** A failing test, lint error, type error, review finding, or alert
   is the abnormality. Work stops until it is understood; the signal is never silenced to resume.
   [S1][S2]
2. **Observe before theorizing.** Reproduce it, or read the whole error, log, profile, or screenshot.
   No fix before the investigation. [S3]
3. **Trace to the origin.** Follow the bad value backward to where it is first produced, not where
   it is first noticed. [S3][S4]
4. **Ask how, across branches.** A failure has several contributors, not one chain of whys. Name at
   least three: the **fault** (the wrong logic), the **guard gap** (why no type, schema, or constraint
   stopped it), and the **detection gap** (why no test, check, or review caught it earlier). [S5][S6][S7]
5. **Stop at a condition you can change, never at a person.** "The developer forgot" is not a cause;
   the system that let forgetting ship is. [S10][S11]
6. **Name the class and find its siblings.** Search for every other instance of the same shape
   before editing.
7. **Fix at the highest altitude that holds,** in this order: make the bad state unrepresentable (a
   type, a schema, a constraint); parse once at the boundary; fix the shared function every caller
   routes through; edit call sites only when they genuinely differ. One change needing edits in many
   places is shotgun surgery: consolidate instead. [S12][S4][S13][S14]
8. **Run the patch test below.** Any patch answer means redesign or escalate.
9. **Close every contributor.** The fault gets the fix; each guard gap and detection gap gets a
   prevention or a detection, or a tracked follow-up with an owner. [S15]
10. **Escalate instead of degrading.** If the right fix exceeds the task, stop and say so. After
    three failed fixes, stop and question the design with the human. [S3]
11. **Prove it.** The reproduction fails before and passes after, the sibling search is clean, no
    signal was suppressed, and one sentence explains why the fault occurred and why it is now
    impossible, not merely unlikely. [S16]

| Issue | Where the cause usually lives | The patch to refuse |
|---|---|---|
| Bug | the producer of the bad state | a guard at the consumer |
| Failing check | the code the check reads | editing the check, its config, or the expected value |
| Review finding | the pattern behind the finding | fixing only the flagged line |
| Flaky test | ordering, time, shared state, network | a retry, a sleep, a longer timeout |
| Perf regression | the algorithm or query a bisect finds | a cache over it, a raised timeout |
| Design finding | the token or the component | a one-off override, `!important`, a z-index bump |

## The patch test

A yes to any of 1 to 7, or a no to any of 8 to 10, means it is a patch.

1. Does it add a condition keyed on a literal: an id, an email, a fixture value? [S17][S18]
2. Does it add a branch only the reported input takes?
3. Does it suppress, catch, skip, retry, loosen, or delete a signal instead of satisfying it?
4. Does it change a test's expected value or remove an assertion, in the same change as the fix,
   without showing the test was wrong? [S17][S18][S28]
5. Does it guard a consumer (a null check, a default, `?.`) against a value the producer should
   never emit? [S4]
6. Does it change timing (a sleep, a timeout, `setTimeout(0)`, a retry) instead of ordering?
7. Does the same edit repeat at several call sites? [S13]
8. Would a same-shaped input with a different value now pass?
9. Does every caller route through the changed code?
10. Would someone writing new code tomorrow be unable to reintroduce it? [S15]

## When the test is wrong

Sometimes the test, not the code, is wrong. That is legitimate and it is also the most common way an
agent cheats: in ImpossibleBench, over 79% of Claude's cheating modified the tests. [S28] So a test is
weakened only with a stated reason. `guard-tests` refuses an edit that removes assertions from an
existing test until `scripts/run-state.sh waive <file> "<why the test is wrong>"` records the
reason in `.polaris/waivers.jsonl`, which is committed and read in review. Then say so to the human.

## The one exception: live harm

Mitigation before understanding is right only while users are being harmed now: an outage, data
loss, a security exposure, or a release blocked with a human's approval. A red check or a review
finding is never live harm. [S22][S23]

- Prefer a reversible mitigation (rollback, flag off, revert) over new code.
- New mitigation code carries its reason on its own line above it, naming the follow-up.
- The follow-up has an owner, a tracking id, and a verifiable end state. [S10][S26]
- The incident flow runs mitigate, then rootcause and prevent. A mitigation with no prevention is
  unfinished. [S15][S24][S25]

## AI failure modes to reject

- Special-casing the test input or returning the expected value. [S17][S18]
- Editing or deleting a test to make it pass. [S28][S31]
- Patching the harness: overriding equality, `sys.exit(0)`, editing conftest outcomes. [S19][S27]
- Suppressing the signal: a catch-all, a lint disable with no reason, a cast, a widened type.
- Trusting a green suite as proof: 29.6% of passing SWE-bench patches behave differently from the
  reference fix. [S30] Green is necessary, not sufficient; the one-sentence explanation is the proof.

## Mechanical help

`check-patterns.sh` flags the shapes it can see with few false positives: a lint or type
suppression with no reason, `@ts-nocheck`, a `noqa` with no code, and, as advisories, a z-index
escalation, a deferred `setTimeout(..., 0)`, and a test-only branch in production code. Everything
else on the list is the reviewer's judgment.
