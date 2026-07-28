# Report: the comment law and the mandatory over-engineering pass

Date: 2026-07-28. Version: 1.8.0. Run log: `.polaris/runs/2026-07-28-flow-code-comment-law.md`.

## What was built

Code Polaris writes now has to explain itself, and the rule has teeth rather than a request.

1. **The comment law** (`rules/core.md`). Doc comments only, at the top of a file and directly above a
   declaration, in the language's multi-line doc syntax. No inline comments, none inside a function
   body, no narration, journal, TODO, or metadata. Before writing a comment, rename or extract.
2. **`rules/clean-code.md`**, the named smell catalog: N1-N7 names, F1-F4 functions, G1-G36 general,
   T1-T9 tests, so a finding is cited rather than argued. Adapted from Clean Code chapter 17 and the
   MIT-licensed clean-dry-code-skills rule set, compressed and made language-agnostic.
3. **`inline-comment` in `patterns.json`** for TypeScript, Python, Go, and Rust: a comment token that
   follows code on the same line.
4. **`guard-edit` blocks.** An inline comment in a written file returns `decision: "block"` with the
   line and the fix. Two strikes per file per session, then advisory.
5. **`guardEdit` defaults on**, in the template and for a config that omits the key.
6. **`hooks/guard-review`** on `SubagentStop` matching the reviewer sends back a review that never
   reports the over-engineering axis, once per reviewer.
7. **`hooks/inject-standard`** on `SubagentStart` puts the comment law and the ladder into every
   code-writing and reviewing subagent, which the session-start injection never reached.
8. **The reviewer's over-engineering lens**, mandatory on every review, reporting as its own axis.
9. **`/flow` phase 5 and `/review-pr` step 4** state the pass is not skippable.
10. **Nine agent files** carry the law in their contract: the six writers, plus bug-fixer,
    code-cleanup, feature-builder, tester, and reviewer.

## Evidence

`bash tests/run-tests.sh`: exit 0, 69 assertions pass, zero failures. Ten are new: the rule flags a
trailing comment in ts and py and names its ID; the doc-block fixtures still pass, which is what
proves a proper multi-line doc comment is not caught; `guard-edit` blocks a comment, keeps `as any`
advisory, still reports it, and degrades after two strikes; `guard-review` blocks a review missing the
axis and only once per reviewer, and passes one that has it; `inject-standard` reaches a writer and
skips a non-code agent.

`guard-edit` also fired live during the run on a fixture written with `as any` and correctly gave
advisory rather than a block.

## Found and fixed during the run

The first new assertion failed under `set -o pipefail`: `check-patterns.sh` exits 1 by design, so
`"$CHECK" ... | grep -q` inherited that failure. Output is captured to a variable now. The first
suite read piped through `tail` and hid the failure line, which is why it took two reads to see.

## Accepted, with rationale

- **The `#` and `//` regexes can false-positive inside a string literal** that contains a space then
  the comment token. Documented in the `quality-gate` notes so a reader confirms the line. A parser
  per language is the alternative, and it is not worth it for a rule whose output a human or an agent
  reads at `file:line`.
- **Only ts, tsx, js, jsx, py, go, and rs are scanned.** Shell, SQL, YAML, and markdown are not,
  because `check-patterns.sh` has no rules for them. The prose standard still covers markdown.
- **Own-line comments inside a function body are not caught deterministically**, only trailing ones.
  The regex would have to know where a function starts. The reviewer's maintainability lens and the
  gate's judgment pass carry that half, and both now name it explicitly.
- **Blocking can, in principle, repeat.** Bounded at two strikes per file per session, then advisory,
  so the worst case is a report rather than a hung turn.

## Residual risk

The plugin runs from an installed cache, so none of this takes effect in a session until the plugin
is updated from the repo. Nothing here is verified against a live subagent run: `guard-review` and
`inject-standard` are tested against their documented payload shapes, not observed firing on a real
reviewer or writer subagent. The first real `/flow` after the plugin update is the test that matters,
and the thing to watch is whether `guard-review`'s keyword check (`over-engineer` or `ponytail`) reads
a genuine report as complete.

## Spend

Telemetry not enabled. Not measured.
