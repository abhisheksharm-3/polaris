# Flow run: the code comment law and the mandatory over-engineering pass

- Task: raise code-quality enforcement so written code explains itself. Doc-block comments only, at
  the top of a file and above a declaration, in multi-line doc syntax. No inline comments. Wire the
  installed clean-code skills into the writers. Give every review a non-negotiable ponytail
  over-engineering pass.
- Date: 2026-07-28
- Path: short. A rules-and-hooks change to the plugin itself, so the spec and design gates collapsed
  into one plan approval.

## Timeline

- Phase 0-1, intake and spec: run inline (opus), no subagent. Task was precise; the plan stood in for
  the spec and was approved by the human before any edit.
- Phase 2, design: read the Claude Code hooks reference at the human's prompt. Found three hooks
  Polaris was not using (`PostToolUse` `decision: "block"`, `SubagentStop` with an agent
  matcher, `SubagentStart`) and one to reject (`type: "prompt"` and `type: "agent"` hooks, 30s and 60s
  per edit). Plan revised to 10 items and approved.
- Phase 4, implement: inline (opus). The comment law in `rules/core.md`; `rules/clean-code.md` adapted
  from the MIT clean-dry-code-skills set and Clean Code chapter 17 after the human ruled out shipping
  more companion skills; `inline-comment` in `patterns.json` for ts, py, go, rust; `guard-edit`
  blocking with a two-strike fallback; new `guard-review` and `inject-standard` hooks; the reviewer's
  over-engineering lens; `/flow` phase 5 and `/review-pr` step 4 made non-negotiable; `guardEdit`
  defaulted on; nine agent files updated.
- Phase 5-6, review and QA: deterministic. 69 assertions pass, suite exit 0. Ten new assertions cover
  the comment rule, the block, the advisory split, the two-strike degrade, `guard-review` once per
  reviewer, and `inject-standard` filtering non-code agents. `guard-edit` also fired live mid-run on a
  fixture and behaved correctly.
- One bug found and fixed during the run: the first new assertion failed under `set -o pipefail`
  because `check-patterns.sh` exits 1 by design, so the pipeline inherited the failure. Captured the
  output to a variable instead. Caught because the first suite read used `tail`, which hid the
  failure line; the second read without `tail` surfaced it.
- Phase 7, docs: `CHANGELOG.md` 1.8.0, version bumped in both manifests, `CLAUDE.md` architecture and
  gotchas, `README.md` standard section, `quality-gate` skill steps 3, 4, and notes.

## Outcome

Stopped at phase 8 by design: built, reviewed, and tested, not committed. No PR, awaiting the human's
go on the commit. Suite exit 0, 69 assertions. Report:
`.polaris/reports/2026-07-28-code-comment-law.md`. Spend not measured, telemetry off.
