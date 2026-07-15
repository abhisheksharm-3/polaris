---
description: Cut a release: changelog, version bump, release notes, and a tag
argument-hint: "[major|minor|patch, or a version]"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write
---

# Release

Cut a release for this project. Read `.polaris/config.json` first (the versioning and tag
conventions live there; ask if unset). Nothing outward-facing (a tag push, a published release)
happens without confirmation unless the config authorizes it.

## Steps

1. **Determine the version.** From `$ARGUMENTS` or by reading the changes since the last tag: a
   breaking change is major, a new feature is minor, a fix is patch. Confirm the number.
2. **Write the changelog.** Dispatch `tech-writer` to add a `CHANGELOG.md` entry for this version
   from the merged changes since the last release, grouped and in the user's terms, not the diff's.
   It passes the writing standard, with no AI attribution.
3. **Bump the version.** Update the version in the manifest and anywhere else it is declared, kept
   consistent across files.
4. **Verify.** Run the full suite and the quality gate. A release is not cut on a red build.
5. **Tag and notes.** Create the tag per the project's convention and prepare release notes from the
   changelog entry. Push the tag and publish the release only after confirmation.

## Rules

- The changelog is honest: what changed, in the user's language, no filler, no AI byline.
- Never cut a release on a failing gate or suite.
