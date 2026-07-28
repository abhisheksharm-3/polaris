# Spec — deterministic capture, prompted global config, and the unused Claude Code surface

> Covers three asks: audit Polaris against the full Claude Code extension surface, fix the memory
> system, and make config for run-from-anywhere commands global instead of cwd-dependent.

## Problem

Three findings, each with evidence.

**1. The automatic layer is not automatic.** `hooks/session-start` writes a factual journal skeleton
in shell, then appends an instruction asking the model to dispatch a background agent to enrich it.
Twelve of the thirteen files in `~/.claude/polaris-memory/journal/` are still `status: facts`; the
only `status: narrative` file is 2026-07-28, written by a manual `/journal`. The work-tracker
reconcile uses the same inject-and-hope pattern. Memory capture has no shell part at all and depends
entirely on the user running `/remember`: `entries/` holds one file, created 2026-07-15 and never
touched. `SessionStart` supports only `command` and `mcp_tool` handlers, so it cannot force any of
this — an injected instruction is the weakest available mechanism, and in practice it is ignored.

**2. `/journal` reads config that `/sweep` deleted.** Sweep moved to user-level config and state in
1.8.0. Nothing followed it. `commands/journal.md:29` reads `sweep.timezone` from
`.polaris/config.json`, `:33` reads `sweep.sources`, `:37` reads `.polaris/work/sweep-state.json`,
`:39` reads `sweep.notionParentPageId`, and `scripts/journal-facts.sh:90` reads
`$cwd/.polaris/work/sweep-state.json`. Sweep's own step-1 migration removes the `sweep` key from the
project config, so on any machine where sweep has run, `/journal` silently loses timezone, sources,
and the sweep-briefing backlink. There is also no prompted way to create sweep's config — it must be
hand-written as JSON, which is why no `~/.claude/polaris-memory/sweep/` directory exists yet.

**3. Polaris uses roughly a third of the extension surface it could.** Unused primitives that bear
directly on these problems: `userConfig` (typed, prompted, user-level plugin options substituted as
`${user_config.KEY}` into skill and agent content), `${CLAUDE_PLUGIN_DATA}`, the `Stop` /
`SessionEnd` / `PreCompact` / `PostCompact` / `TaskCompleted` hook events, `prompt` and `agent` hook
handler types, agent `tools` / `disallowedTools` / `effort` / `memory` / `maxTurns` / `isolation`,
command-level `model` and `disable-model-invocation`, skill `context: fork`, and skill progressive
disclosure.

## Scope

**In:**

- Fix the five stale sweep references in `/journal` and `journal-facts.sh`.
- Declare sweep's scalar config as `userConfig` options in `plugin.json`, so Claude Code prompts for
  them at install and stores them in user settings; keep the nested `sources` object in the
  user-level JSON file.
- Replace both inject-and-hope instructions with a `Stop` hook that blocks once per session when
  there is un-enriched journal or unreconciled tracker work outstanding.
- Add deterministic memory capture on the same `Stop` hook.
- Resolve the two-memory-systems conflict (`rules/memory.md` requires the reader to maintain
  `~/.claude/polaris-memory/` by hand while Claude Code's native auto-memory at
  `~/.claude/projects/<project>/memory/` loads itself every session).
- Least-privilege pass on the fleet: `tools` on the 26 agents, `model` on the 29 commands, and
  `allowed-tools` on `commands/gate.md`, the one command missing it.

**Out** (reported, not built — each is its own effort):

- Skill progressive disclosure. `skills/ui-prototype/SKILL.md` is 60 KB and `ui-new` 44 KB, both
  flat, both loaded whole. Splitting them into `references/` and `scripts/` is a large mechanical
  change with its own risk.
- Rewriting `/flow` as a real `workflows/*.js` script instead of prose the model interprets.
- Making `/catchup` cross-project. It reads only the current project's `streams.md`, so the same
  cwd-dependence applies, but fixing it needs a project registry that does not exist yet.
- Sandboxing config, LSP servers, monitors, themes, statusline, channels.

## Design

### Fixed decisions

**Config split by shape, not by preference.** `userConfig` option types are `string`, `number`,
`boolean`, `directory`, and `file`. Sweep's `notionParentPageId`, `timezone`, and `maxLookbackHours`
are scalars and become `userConfig` options. `sources` is a nested object of per-connector queries
and channels, which no `userConfig` type expresses, so it stays in
`~/.claude/polaris-memory/sweep/config.json`. Resolution order for a scalar: the `userConfig` value
when set, else the same key in the JSON file, else sweep's existing not-configured stop. This keeps
the shipped migration path working and adds a prompted path for new users.

**Memory keeps its own store; the duplication is removed from the rule, not the store.** Native
auto-memory is per-project-directory, so it cannot hold the cross-project facts Polaris needs, and
`autoMemoryDirectory` pointing several projects at one directory would make every project load every
other project's memory. `~/.claude/polaris-memory/` stays. What changes is that `rules/memory.md`
stops asking the model to maintain it by hand and instead documents that the `Stop` hook drives
capture, with `/remember` as the manual override.

**Capture uses a `Stop` command hook that blocks, not an injected instruction.** `Stop` accepts
`command` handlers and honors top-level `decision: "block"` with a `reason` fed back to the model,
which is the only mechanism that makes the follow-up work mandatory rather than optional. The hook is
a shell script: it finds outstanding work (journal files whose frontmatter says `status: facts`, a
tracker snapshot since the last reconcile, a session transcript not yet scanned for memory-worthy
facts), and if there is any, exits 0 with `{"decision":"block","reason":"..."}` naming the exact
files. Guards, both required to avoid a loop and to keep the cost bounded:

- If the hook input's `stop_hook_active` is true, exit 0 immediately. This is the documented
  loop-breaker.
- A per-session marker under `${TMPDIR}/polaris-stop-capture/<session_id>` makes the hook block at
  most once per session, following the existing `guard-edit` and `guard-review` precedent.

`type: "agent"` handlers are the tempting alternative — they would do the work in a subagent without
touching the main thread — but they are documented as experimental and it is not established that an
agent hook may write files, so this spec uses the non-experimental path. Revisit if the block proves
disruptive.

**Least privilege is derived, not invented.** Each agent's `tools` list comes from what its own
prompt already tells it to do; no agent gains a capability. The 29 commands get `model` matching
`rules/model-routing.md`, which already assigns tiers but has no mechanism to enforce them.

### Changes

1. `commands/journal.md` — read `timezone`, `sources`, and `notionParentPageId` through sweep's
   resolution order; read state from `~/.claude/polaris-memory/sweep/state.json`.
2. `scripts/journal-facts.sh:90` — read the user-level sweep state path.
3. `.claude-plugin/plugin.json` — add `userConfig` with `notionParentPageId`, `timezone`,
   `maxLookbackHours`.
4. `commands/sweep.md` — step 1 resolves scalars from `${user_config.*}` first, then the JSON file,
   then stops as today. Migration behavior unchanged.
5. `hooks/stop-capture` (new) + `hooks/hooks.json` — wire `Stop`.
6. `hooks/session-start` — delete the two injected directives the `Stop` hook replaces; keep the
   deterministic skeleton and snapshot writes.
7. `rules/memory.md` — document hook-driven capture; drop the by-hand framing.
8. `agents/*.md` (26) — add `tools`.
9. `commands/*.md` (29) — add `model`; add `allowed-tools` to `gate.md`.
10. `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — bump both to 1.9.0.
11. `CHANGELOG.md`, `CLAUDE.md`, `README.md` — record the new hook, the `userConfig` options, and the
    capture model.

## Acceptance criteria

```
Given /sweep has migrated and .polaris/config.json has no sweep key
When /journal runs for a day
Then it resolves timezone, sources, and notionParentPageId without reading .polaris/config.json
And it finds the sweep briefing backlink from ~/.claude/polaris-memory/sweep/state.json
```

```
Given a fresh install with no sweep config
When the user installs or configures the plugin
Then Claude Code prompts for notionParentPageId, timezone, and maxLookbackHours
And /sweep resolves them without a hand-written JSON file
```

```
Given a journal file whose frontmatter says status: facts
When the model tries to end its turn and stop_hook_active is false and the session marker is absent
Then the Stop hook returns decision: block with a reason naming that file
And the model enriches it to status: narrative before stopping
```

```
Given the Stop hook already blocked once this session
When the model tries to end its turn again
Then the hook exits 0 and does not block
```

```
Given stop_hook_active is true
When the Stop hook runs
Then it exits 0 immediately, whatever work is outstanding
```

```
Given nothing outstanding — no status: facts journal file, no tracker delta, no unscanned transcript
When the model ends its turn
Then the hook exits 0 silently and the turn ends normally
```

```
When bash tests/run-tests.sh runs
Then it passes, and check-agents.sh and check-commands.sh accept every added tools and model field
```

## Risks

- **The `Stop` block is user-visible.** It costs one extra turn per session when work is outstanding.
  If that reads as the assistant refusing to stop, the mitigation is to narrow what counts as
  outstanding, to journal enrichment only, rather than to widen the guards.
- **Memory capture quality is unproven.** Deciding what is worth remembering from a transcript is a
  judgment call, and a hook that forces it every session could produce noise instead of one entry in
  thirteen days. The `Stop` reason must state the bar explicitly, and this needs QA against real
  transcripts before it ships.
- **`tools` on 26 agents can break a working agent** by omitting a tool its prompt depends on. Each
  list is derived from the agent's own prompt, and the fleet checks plus a smoke run cover it.
