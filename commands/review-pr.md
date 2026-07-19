---
description: Review an existing pull request across dimensions, verify findings, and check for over-engineering
argument-hint: "<PR number or URL>"
allowed-tools: Task, Read, Bash, Grep, Glob, WebFetch
---

# Review a PR

Review the pull request in `$ARGUMENTS` as the harshest fair reviewer on the team. Read
`.polaris/config.json` first.

## Steps

1. **Get the diff.** Fetch the PR diff and description (`gh pr diff`, `gh pr view`). Understand what
   it claims to do before judging how it does it.
2. **Review per dimension.** Dispatch `reviewer` for each lens the diff warrants: correctness (every
   reachable state and edge case), security, performance, maintainability, simplicity, and
   accessibility for UI. Collect findings with `file:line` and severity.
3. **Check spec conformance.** Dispatch `reviewer` with the spec-conformance lens: locate the spec
   source (the issue reference in the PR or commits, or a spec file under `.polaris/specs/`), check
   the diff against its acceptance criteria, and report unmet criteria as a separate axis from the
   quality findings. <!-- spec-conformance credits code-review from mattpocock/skills -->
4. **Check for over-engineering.** Run `/ponytail-review` on the diff: is there a simpler path, a
   reused helper, a stdlib or native feature, or a one-liner that the PR missed.
5. **Verify.** Dispatch `verifier` to confirm each finding is real and reproducible; drop the false
   positives. A finding with no reproducible trigger is labeled plausible, not confirmed.
6. **Report.** Post or return a review: the confirmed findings ordered by severity, each with a
   concrete fix, plus the over-engineering notes. Separate blockers from suggestions. Acknowledge
   what the PR did well.

## Rules

- Review the diff, not the whole codebase, unless a change forces a wider look.
- Every finding is defensible with evidence; do not pad the review to look thorough.
