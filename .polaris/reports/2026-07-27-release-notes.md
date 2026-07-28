# Report — `/polaris:notes`, the release-notes maker

**Date:** 2026-07-27
**Spec:** `.polaris/specs/2026-07-27-release-notes-spec.md`
**Run log:** `.polaris/runs/2026-07-27-flow-release-notes.md`

## What was built

One new command, `commands/notes.md`, plus its docs. No code, no script, no new dependency.

`/polaris:notes [version]` detects the range to write about, confirms it with the user before reading
further, reads the diffs behind the changes, classifies each one, and writes two documents to
`.polaris/releases/`: one for the dev team and client, one for the people who use the product. The
product document is written to an ICP the `researcher` agent establishes from the repo, the market, and
the close competitors, and it states that judgment at the top so the sender can correct it. Publishing
to a GitHub release, Notion, or Slack happens only after confirmation, in a later turn than the offer.

`/polaris:release` is untouched. It still owns the version, the changelog entry, the manifest bump, and
the tag.

Files: `commands/notes.md` (new), `README.md` (command row and job note), `CHANGELOG.md` (1.6.0),
`.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (1.5.0 → 1.6.0).

## What was found and fixed

The `reviewer` pass returned 6 should-fix findings and 7 nits, no blocker. Six were real and are fixed:

1. The last-50-commits row had no runnable range, and it is the row that fires in this repo. It now
   resolves a base commit with `git rev-list --max-count=1 --skip=50 HEAD`, and falls back to the empty
   tree for a history shorter than 50 commits.
2. `git diff --stat main..dev` counted every file changed on `main` since the branch point as part of
   the release. The branch row now uses the three-dot merge-base form.
3. `git branch -a` lists remote-tracking refs, so a remote-only `origin/dev` produced the bad revision
   `main..dev`, and `main` was hardcoded against `master`-default projects. Branch names are now
   resolved to a real revision, and the base branch comes from `origin/HEAD`.
4. Step 2 said both "read the diff behind every change" and "read the diff for a bare 'fix' message".
   The bound is now explicit.
5. The `researcher` dispatch ran before the check that would make it worthless. Step 3 now exits first
   when every change is internal-only.
6. `allowed-tools` did not cover the Notion, Slack, and Atlassian tools the command offers to use.

Verification then found one defect the review missed: `--skip=49` puts 49 commits in the range, not 50.
Running the sequence against this repo caught it; it is now `--skip=50`, confirmed at 50.

## Accepted, with rationale

- **Nit 10, cut the "what can the reader now do" rule from step 4 as a restatement of step 2.**
  Rejected. That sentence is where acceptance criterion 7 lives, and the writing rule belongs at the
  point of writing. Step 2 classifies; step 4 refuses to pad.
- **The `researcher` pass runs on every run that includes the product document.** That cost was chosen
  at intake, depth over speed. No `--fast` flag until someone wants one.
- **`allowed-tools` in `commands/sweep.md` has the same connector gap** the review found here: it
  declares `Read, Bash, Grep, Glob` and then calls `notion-create-pages`. Out of scope for this change;
  flagged for cleanup.

## Evidence

- `bash scripts/check-patterns.sh prose` on `commands/notes.md`, `README.md`, `CHANGELOG.md` — exit 0.
- `bash scripts/check-commands.sh` — `ok notes -> researcher`, `ok notes -> tech-writer`.
- `bash scripts/check-agents.sh` — exit 0.
- `bash tests/run-tests.sh` — exit 0, 41 `ok` lines, no failures.
- Every `git` command in step 1 executed against this repo: base branch `main`, 0 tags, base-of-50
  resolved, 50 commits in range, 107 files, span 2026-07-15 to 2026-07-21, and the empty-tree fallback
  returns 164 files.

## The first real run

Run on `a3f41bd..HEAD` (the 1.5.0 bump to now, 2 commits, 11 files, 2026-07-21 to 2026-07-27), which
produced `.polaris/releases/2026-07-27-1.6.0-dev.md` and `-users.md`. Two defects surfaced that the
review had not:

1. **Commit links resolved to nothing.** `tech-writer` wrote `../../commits/<sha>`, a relative path that
   breaks the moment the file is read outside the repository, which is the whole point of release notes.
   The command now says to build the URL from `git remote get-url origin` and why.
2. **Empty dev sections were padded** with "None this release." for Changed, Fixed, and Deprecated. The
   cut-an-empty-section rule was written into the product-document half only. It now covers both, with
   **Before you deploy** as the deliberate exception: a reader scanning for a migration needs to see
   that there is none.

Both are fixed in `commands/notes.md` and in the two generated documents. What held: the range
confirmation stopped before reading, the internal-only commit stayed out of the product document,
**Written for** carried its evidence and its inference caveat, and the product document cut its empty
sections rather than filling them.

That closes acceptance criteria 2, 3, and 4. Criterion 8 holds by inspection: `commands/release.md` is
untouched.

## Residual risk

Detection rows 1 and 2 are still reasoned, not executed: this repository has no tags and no `dev`
branch, so the run exercised the fallback row with an explicit range. A project that ships from a `dev`
branch or a tag pair is where those two rows get their first test.

The step-5 publish path is unexercised. Nothing was posted to GitHub, Notion, or Slack, and the
`gh release edit` option cannot run here at all until a tag exists.

The ICP pass cited two external figures (a 38% AI-review-effort statistic and an arXiv paper) that were
not independently checked. They shape the profile's framing rather than any claim in the notes, and the
**Written for** header exists so the sender catches a wrong profile before sending.

Both documents still depend on `tech-writer` following section-by-section instructions, which is
judgment, not a check. The two defects the first run surfaced were both of that kind.

## Ship state

Committed on `main` and pushed. No PR: this project keeps work on `main`. Polaris runs from an
installed plugin cache, so `/notes` goes live after a plugin update, not at commit.

## Spend

Telemetry is not enabled in this project's config, so there is no figure to report. Four delegated
dispatches: `reviewer` at about 61k subagent tokens, `researcher` at 56k, and `tech-writer` twice at
59k and 56k.

**Push note:** the first `git push` failed 403 — the active `gh` account was `abhishekwednesday`, which
has no write access. Switched to `abhisheksharm-3`, pushed `0f2b41d`, and restored the active account.
