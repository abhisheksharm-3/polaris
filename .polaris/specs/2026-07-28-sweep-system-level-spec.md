# Spec — move `/sweep` to user-level state, with a migrating first run

> Extends the built `/sweep` (`commands/sweep.md`). Makes sweep's config and state user-level and
> cross-project, and migrates a legacy project-level config on the next run rather than starting over.

## Problem

`/sweep` read its `sweep` block from each project's `.polaris/config.json` and wrote its cursor to
`.polaris/work/sweep-state.json`. For a single user running sweep across many projects, that scattered
one personal config across repos and risked committing it into a client repo. Sweep is a personal
operating tool; its config and state belong at the user level, once, shared across projects. An
existing user must not lose their configured sweep or its cursor in the move.

## Scope

In: changes to `commands/sweep.md` only. Config moves to `~/.claude/polaris-memory/sweep/config.json`
(the sweep object's contents, no longer nested under a `sweep` key). State moves to
`~/.claude/polaris-memory/sweep/state.json`. The next run migrates a legacy project-level `sweep`
block and state file up, then removes the `sweep` key from the project config.

Out: no change to what sweep pulls, tiers, carries, or writes to Notion. No new script. No change to
`.polaris/config.json`'s other keys. No cron.

## Design

**Fixed paths (unchanged invariant, new values).** The write target stays `notionParentPageId` from
the resolved config; the state path is fixed at `~/.claude/polaris-memory/sweep/state.json`. No source
content redirects either. The migration is the one bounded write the command makes outside the
user-level `sweep` and `okr` directories, and it is declared in the command's fixed-values preamble.

**Config resolution (step 1), in order:**

1. `~/.claude/polaris-memory/sweep/config.json` exists → use it.
2. Else the project `.polaris/config.json` has a `sweep` block → migrate once: copy the block's
   contents up to the user config; move `.polaris/work/sweep-state.json` up to `state.json` if it
   exists; remove only the `sweep` key from the project config; report what moved; proceed.
3. Else → not configured; print the block to create at the user path; stop, write nothing.

## Acceptance criteria

```
Given ~/.claude/polaris-memory/sweep/config.json exists
When /sweep runs
Then it uses that config and does not touch any project .polaris/config.json
```

```
Given no user-level sweep config, and the project .polaris/config.json has a sweep block plus other keys,
  and .polaris/work/sweep-state.json exists
When /sweep runs
Then the sweep block's contents are written to ~/.claude/polaris-memory/sweep/config.json
And .polaris/work/sweep-state.json is moved to ~/.claude/polaris-memory/sweep/state.json
And the project .polaris/config.json keeps its other keys and no longer has a sweep key
And the run reports what moved before pulling any source
```

```
Given neither a user-level config nor a project sweep block
When /sweep runs
Then it stops, writes nothing, and prints the config to create at the user path
```

```
Given the finished command file
Then every line passes the writing standard (rules/writing.md)
```

## Assumptions for the approval gate

1. **Config file holds the sweep object directly** (not nested under `sweep`), since the file is the
   sweep config. Confirmed by the user-level move.
2. **Migration moves and removes** the project-level block and state (user's explicit choice over a
   non-destructive copy). Reversible via git if unwanted.
3. **The migration write is the only write outside the user-level dirs**, one-time, declared in the
   preamble. The injection guarantee holds because paths are fixed in the command, never derived from
   source content.
