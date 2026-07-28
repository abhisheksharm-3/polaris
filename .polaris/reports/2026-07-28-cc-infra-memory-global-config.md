# Report — deterministic capture, prompted global config, and the unused Claude Code surface

- Date: 2026-07-28
- Spec: `.polaris/specs/2026-07-28-cc-infra-memory-global-config-spec.md`
- Plan: `.polaris/plans/2026-07-28-cc-infra-memory-global-config.md`
- Run log: `.polaris/runs/2026-07-28-flow-cc-infra-and-global-config.md`
- Version: 1.9.0, on `main` as `bf131a8`, `d0a1315`, `68bbb05`, `546eada`. Pushed, CI green in 12s (run 30383270921).

## What was asked

Three things: audit Polaris against the full Claude Code extension surface, improve the memory
system, and make config for commands that run from anywhere global instead of dependent on the
directory the terminal happened to be in.

## What was found

**The memory system's problem was capture, not schema.** `~/.claude/polaris-memory/entries/` held one
file, created 2026-07-15 and never touched, against thirteen daily journal files in the same store.
Twelve of those thirteen were still `status: facts`: the shell skeleton landed every day, and the
instruction asking for the narrative was ignored every time. The work tracker used the same pattern.
The cause is structural. `SessionStart` accepts only `command` and `mcp_tool` handlers, so a hook
there can inject a request and nothing more. Everything that depended on the model honoring that
request did not happen.

**The global-config complaint was already a live bug.** `/sweep` moved its config and state to
`~/.claude/polaris-memory/sweep/` in 1.8.0, and its own migration strips the `sweep` key from the
project config. Nothing followed it: `commands/journal.md` still read `sweep.timezone`,
`sweep.sources`, and `sweep.notionParentPageId` from `.polaris/config.json`, and both it and
`scripts/journal-facts.sh` read `.polaris/work/sweep-state.json`. On any machine where sweep had run,
`/journal` silently lost the timezone, the source queries, and the briefing backlink. Separately,
sweep had no prompted setup path at all, only a hand-written JSON file, which is why no
`~/.claude/polaris-memory/sweep/` directory existed on this machine.

**Polaris used roughly a third of the surface available to it.** Unused and relevant: `userConfig`,
`${CLAUDE_PLUGIN_DATA}`, the `Stop` / `SessionEnd` / `PreCompact` / `PostCompact` / `TaskCompleted`
events, `prompt` and `agent` hook handlers, agent `tools` / `disallowedTools` / `effort` / `memory` /
`maxTurns` / `isolation`, command `model` and `disable-model-invocation`, skill `context: fork`, and
skill progressive disclosure.

## What was built

1. **`hooks/stop-capture` on `Stop`.** Blocks once per session when a journal day inside the last 14
   days is still `status: facts` or the work tracker has an unreconciled window, and asks for the
   narrative, the reconcile, and a memory pass. `Stop` honors a block decision, which is the only
   mechanism that makes the follow-up mandatory. The two dead directives and the whole
   `polaris_worktracker` function left `hooks/session-start`.
2. **`/sweep`'s three scalars are `userConfig` options**, prompted at install and stored in user
   settings. `sources` has no scalar form among the option types, so it keeps its file.
3. **The stale sweep paths in `/journal` and `journal-facts.sh` are fixed**, and a day whose only
   record is a sweep briefing now counts as a day.
4. **Least privilege**: `tools` on all 27 agents, `model` on all 29 commands, `allowed-tools` on
   `gate.md`, and `check-agents.sh` rejecting an unknown tool name.

## What was found and fixed during review and QA

The review and QA passes were the most productive part of the run. Fourteen review findings and
twelve QA findings, including three of mine that would have shipped:

- **`cut -c1-9500` never bounded the reason.** `cut` is line-oriented; a five-line 15,005-character
  input came back at 15,005 characters. The harness truncates from the end, and the end held the
  memory instruction, so the third of three requested actions was dropped exactly when the tracker
  had most to say. Now `head -c`, with every instruction emitted before the untrusted snapshot.
- **A control-byte stripping pipeline defending a failure that cannot occur.** `jq --arg` already
  escapes control bytes and already replaces invalid UTF-8. The CHANGELOG claimed a bug that never
  existed; both the code and the claim are gone.
- **An `awk` regression that would have shipped the feature completely inert.** The rewritten
  frontmatter check used `exit 0` in a rule alongside `END{exit 1}`. awk runs `END` on its way out, so
  `END`'s status won and every journal file read as not pending. The hook would have blocked nothing,
  ever, which is precisely the failure it was built to fix. Caught by a test of my own, one step after
  writing it.
- **The give-up counter added in review was worse than what it fixed.** One malformed word in its
  state file aborted the whole hook under `set -u`; an unparseable count froze the counter so a day
  was asked forever; a filename with a regex metacharacter wiped every other day's history; and
  concurrent runs both lost and double-counted increments. A stateless 14-day window replaced it and
  removed four findings and fifteen lines at once.
- **A withheld snapshot advanced the cursor**, making that window unreachable, since the snapshot only
  reads forward. The hook now never advances the cursor on any path; the reconcile stamps it on
  completion, so an interrupted pass costs a repeated ask rather than lost data.
- Plus: the once-per-session marker became an atomic `mkdir`, so eight parallel stops block once
  instead of eight times, an unclaimable marker suppresses the block instead of blocking every turn,
  and a planted symlink cannot redirect the write; unsafe session ids are rejected rather than mangled
  into a shared key; an invalid or empty cursor reseeds instead of handing `git log --since` a date it
  ignores while returning the entire history as the delta; a two-object payload no longer defeats the
  loop-breaker; the frontmatter scan is bounded; and a screen that fails to run is reported as that,
  not as an injection attempt.

## Accepted with rationale

- **24 of the 27 agent tool lists are identical and restrict nothing.** Every agent's contract already
  mandates the docs protocol and writing into `.polaris/`, so the lists converge by design. This was
  flagged before the work started and again by the reviewer independently; the human chose full
  allowlists knowing it. The value is concentrated in `reviewer`, `verifier`, and `prod-audit`.
- **Command-level `model` caps what `rules/model-routing.md` calls a floor.** Flagged before
  implementing: a user on Opus running a Sonnet-tiered command is downgraded. The human chose it
  anyway, so all 29 carry a tier.
- **`check-agents.sh` keeps a hand-copied tool roster.** It will go stale on a Claude Code release. The
  reviewer proposed a shape check instead, but a shape check accepts `Wrtie`, which is the entire
  failure this catches.
- **`allowed-tools: Task`** stays across ten-plus commands. `Task` is a documented alias for `Agent`
  since v2.1.63, so renaming would be churn.

## Residual risk

- **The push needed an account switch.** `git push` first returned 403: the active `gh` account was
  `abhishekwednesday` and the repo is `abhisheksharm-3/polaris`. Resolved by switching to
  `abhisheksharm-3`, pushing, and switching back, so global `gh` state is as it was. Worth knowing
  next time, since the wrong account is the default.
- **The plugin runs from an installed cache**, so none of this is live until the plugin is updated.
- **Memory capture quality is unproven.** Nothing here shows a forced pass produces one good entry
  rather than three mediocre ones. The bar is stated in the block reason; a real week of use will say
  whether it holds.
- **The block is user-visible**, costing one extra turn per working session. If it reads as the
  assistant refusing to stop, narrow what counts as outstanding rather than widening the guards.
- **Two concurrent sessions in one project can reconcile the same window twice.** Unchanged from the
  code this replaced, which carried the same acknowledged ceiling.
- **A symlink named `YYYY-MM-DD.md` inside the journal directory is followed.** Needs a planted
  symlink in a user-owned directory to matter.
- **Never exercised end to end in a real session.** Every test drives the hook with crafted payloads.
  The first genuine `Stop` in a session with an unenriched journal day is the real proof, and it has
  not happened yet.

## Left undone, deliberately

Reported, not built, each its own effort: splitting the 60 KB `ui-prototype` and 44 KB `ui-new` skills
for progressive disclosure; rewriting `/flow` as a real `workflows/*.js` script instead of prose the
model interprets; making `/catchup` cross-project, which has the same cwd dependence but needs a
project registry that does not exist. `.polaris/specs/memory-freshness.md` is now stale: it scoped out
session-end capture on the grounds it was already covered, and the disk evidence refuted that.

## Spend

Four subagents: docs research (opus, 347k tokens), primitive audit (sonnet, 70k), review (opus, 100k),
QA (opus, 109k). Telemetry is not enabled, so there is no dollar figure.
