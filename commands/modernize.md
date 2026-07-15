---
description: Upgrade dependencies or a framework safely: read the migration guide, upgrade, fix breakages, verify
argument-hint: "<dependency or framework, or 'all outdated'>"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write, WebFetch, WebSearch
---

# Modernize

Upgrade `$ARGUMENTS` without breaking the build. Read `.polaris/config.json` first and honor it.
Nothing outward-facing happens without confirmation unless the config authorizes it.

## Steps

1. **Survey.** Detect the current versions from the manifest and lockfile. Identify the target
   version and everything between current and target.
2. **Read the path.** Fetch the changelog and the migration guide via the docs protocol (`llms.txt`
   or the release notes) for every major version crossed. List the breaking changes that touch this
   codebase, not the whole changelog.
3. **Plan the hops.** For a large jump, upgrade one major version at a time, not all at once. State
   the order and the risky steps.
4. **Upgrade.** Bump the version, run the official codemods where they exist, and update the lockfile.
   One concern per commit.
5. **Fix breakages.** Build and run the tests; hand each breakage to `bug-fixer` for a proper fix,
   not a shim. Deprecations become the new API, not a silenced warning.
6. **Verify.** Run the full suite and the quality gate. Dispatch `verifier` to confirm behavior is
   unchanged where it should be, and correctly changed where the upgrade intends it.
7. **Record.** Update the changelog via `tech-writer` and note any deferred follow-up.

## Rules

- Upgrade through majors in order; do not skip the migration guide.
- A breakage gets a real fix, never a compatibility shim that hides the change (unless the config
  says maintain backward compatibility).
- Evidence before claims: show the build and the tests green.
