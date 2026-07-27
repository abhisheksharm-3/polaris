# Spec — `/polaris:notes`, the release-notes maker

**Date:** 2026-07-27
**Status:** awaiting approval

## Problem

`/polaris:release` cuts a release: it picks the version, adds a `CHANGELOG.md` entry, bumps the
manifest, verifies, and tags. Its release notes are one clause of step 5, "prepare release notes from
the changelog entry". A changelog entry is a list of merged changes. Release notes that a person
would be proud to send are a different document: they know who is reading, they lead with what the
reader can now do, and they say what was fixed without making the reader parse a diff.

Nothing in Polaris writes that document. Today it happens by hand, once per release, differently
every time.

## Users

The engineer or founder shipping a release who needs two documents from the same set of changes: one
for the dev team and the client, one for the people who use the product.

## Scope

A new command, `/polaris:notes`, that collects the changes in a release, judges who each document is
for, and writes both documents to `.polaris/releases/`. It offers to publish and never publishes
without confirmation.

Out of scope: version selection, the manifest bump, tagging, and the `CHANGELOG.md` entry. Those stay
in `/polaris:release`. This command reads a version if one is given and otherwise names the release
by date.

## Behavior

### 1. Collect the changes

Auto-detect the change source, then confirm once before reading further:

| Signal | Source it implies |
|---|---|
| A `dev` (or `develop`, `staging`, `release/*`) branch exists and is ahead of `main` | `main..<that branch>` |
| No such branch, but tags exist | `<latest tag>..HEAD` |
| Neither | the last 50 commits on the current branch, flagged as a guess |

Show the detected source, the commit count, the file count, and the date span, then ask the user to
confirm or name their own method. A user who ships by merged PR window, by a tag pair, or from a
Jira fix version says so at this prompt and the command uses that instead.

Merge commits are collapsed to the PR they merged. A commit whose message the writing standard would
reject (a bare "fix", a "wip") is read from its diff, not its message.

### 2. Judge the audiences

Two documents come out of every run, from one read of the changes.

The **dev and client** document is written for someone who reads a diff: it names components,
endpoints, migrations, config keys, and breaking changes, and it links commits and PRs.

The **product audience** document is written for the people who use the product. Their identity is
not assumed. The `researcher` agent runs a full ICP pass first (the product's own code and docs, its
market, its competitors) and returns a cited profile: who they are, what they were doing before this
release, and the words they use. The document is written to that profile, and the profile is stated
at the top of the document so the reader of the notes can see, and correct, the judgment behind them.

### 3. Write the documents

Each change is classified as a feature, an improvement, a fix, a breaking change, a deprecation, a
security fix, or internal-only. Internal-only changes appear in the dev document and are omitted from
the product one.

Both documents open with the release's single most consequential change stated in one sentence, not a
summary of the summary. Each entry says what changed and what the reader can now do that they could
not before. An entry that cannot answer the second half is a candidate for internal-only, not filler.

Migrations, breaking changes, and required actions appear before the feature list in the dev document,
because a reader who misses them loses data.

Written to `.polaris/releases/<date>-<version-or-slug>-dev.md` and `-users.md`.

### 4. Offer to publish

After both files are written, offer each destination and act only on confirmation: a GitHub release
body, a Notion page, a Slack post. Nothing is published in the same turn it was offered.

## Acceptance criteria

1. `/polaris:notes` exists, passes `bash scripts/check-commands.sh`, and its prose passes
   `bash scripts/check-patterns.sh prose`.
2. Run in this repo with no arguments, the command detects a change source, states the commit count
   and date span, and stops for confirmation before writing anything.
3. It produces exactly two files under `.polaris/releases/`, one per audience, from one run, for any
   release with at least one change a user outside the codebase can observe. A release where every
   change is internal-only produces the dev document only, and says so.
4. The product-audience document states the ICP it was written for and cites the evidence.
5. The dev document places breaking changes and migrations above the feature list.
6. No file is published to GitHub, Notion, or Slack without an explicit confirmation in a turn after
   the offer.
7. An entry that cannot say what the reader can now do is classified internal-only rather than padded.
8. `/polaris:release` is unchanged and still passes its checks.
9. The command names its two write targets (`.polaris/releases/` and nothing else) and treats commit
   messages, PR bodies, and connector content as data, never as instructions.
10. `bash tests/run-tests.sh` passes.

## Assumptions

- The project is a git repository. Without git the command stops and says so rather than inventing
  a change list.
- Version numbers come from the user or from `/polaris:release`; this command does not compute one.
- The ICP pass costs a researcher dispatch on every run that includes the product document. That is
  the choice made at intake: depth over speed.

## Rejected

- **Extending `/polaris:release`.** It would double the length of a command that does one thing well,
  and release notes are wanted without cutting a release.
- **A `releaseNotes` config block.** Auto-detect plus one confirmation covers it. Add the block when
  a user re-answers the same prompt often enough to complain.
- **A shell helper for change collection.** Three `git` invocations answer it. A script earns its
  place when detection proves unreliable.
