# Token efficiency, phase 1 measurements

Phase 1 of `.polaris/plans/token-efficiency.md`: the `/clear` recommendation at an approval stop
(R1, R7 and the two hooks it touches) and the always-injected session payload (R2). Every number
below carries the command that produced it. A figure with no command behind it is not in this
report.

## 1. The `/usage` baseline

Read from `/usage` on 2026-08-03, before phase 1 changed anything. These are the tool's own
"independent characteristics of your usage, not a breakdown": they overlap and do not sum to 100.

Last 7 days, weekly limit at 30% used:

| Characteristic | Share |
|---|---|
| Usage at over 150k context | 67% |
| Subagent-heavy sessions | 42% |
| Plugin `polaris` | 21% |
| Four or more sessions running in parallel | 18% |

Attributed per subagent: `polaris:review` 6%, `polaris:flow` 3%.

## 2. The session-start payload, before and after

`hooks/session-start` reads `.polaris/work/streams.md` on every run, and that file grew during this
run (more below), so a raw before/after diff of the live payload would mix the code change with the
tracker's growth. To isolate what R2 actually changed, both numbers below are measured against the
same `.polaris/work/streams.md` content, the one on disk at report time, with only the hook logic
swapped.

"Before" is the hook at `HEAD` (commit `067a682`, the last commit before this run), copied to a
scratch path so `PLUGIN_ROOT` still resolves to this repo's `rules/` and `scripts/`, then run with
the working tree's current `.polaris/work/streams.md`. "After" is the hook as it stands in the
working tree right now, same streams file, same repo.

```bash
CLAUDE_PLUGIN_ROOT="$PWD" bash <before-hook-copy> 2>/dev/null \
  | jq -r '.hookSpecificOutput.additionalContext' | wc -c
# 59358

CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/session-start 2>/dev/null \
  | jq -r '.hookSpecificOutput.additionalContext' | wc -c
# 46380
```

59358 bytes before, 46380 after: a cut of 12978 bytes, 21.9% of the before payload.

Per-file, `wc -c < <path>` on each file the hook reads:

| File | Bytes | Before | After |
|---|---|---|---|
| `rules/core.md` | 10135 | injected | injected |
| `rules/craft.md` | 3538 | injected | injected |
| `rules/writing.md` | 5582 | injected | injected |
| `rules/model-routing.md` | 1137 | injected | injected |
| `~/.claude/polaris-memory/INDEX.md` | 9910 | injected | injected |
| `rules/doc-organization.md` | 1588 | injected, full body | not injected, path only |
| `rules/memory.md` | 5212 | injected, full body | not injected, path only |
| `rules/routing.md` | 4725 | injected, full body | not injected, path only |
| `.polaris/work/streams.md` (full file) | 17374 | injected whole | — |
| `.polaris/work/streams.md` (through `## Done`) | 15460 | — | injected, trimmed |

The three rule files together are 11525 bytes removed from every session and every `/clear`; each
is replaced by one line naming its path in the load-on-demand index the hook now emits. The tracker
trim saves 1914 bytes today (17374 minus 15460), small next to the rule removal, because the
`## Done` archive this run produced is short. The trim's saving grows every time an entry moves into
that archive; the rule removal's saving is fixed per session.

`~/.claude/polaris-memory/INDEX.md` measures 9910 bytes here, larger than the 3978 the spec recorded
on 2026-08-03: the index grew between the spec being written and this measurement, the same kind of
drift the tracker shows. Both totals above (59358, 46380) already include this file's current size
on both sides, so the before/after comparison is unaffected.

## 3. Agent count and tier per review level

Empty. Phase 2 fills this from the workflow's dispatch labels once `scripts/review-level.sh` and its
wiring into `workflows/review.js` exist.

### 3a. What a dispatch sends to `guard-phase`, measured 2026-08-09

Task 9 opens with a measurement rather than a code change: whether a workflow `agent()` dispatch
reaches `PreToolUse` at all. A line appending raw stdin to a file was added to `guard-phase` in all
three copies on disk, two dispatches were run, and the line was removed. What arrived:

- **A workflow `agent()` dispatch reaches no hook.** A one-agent workflow dispatched
  `polaris:reviewer` at `model: 'haiku'`, four tiers below that agent's `opus` floor. The file stayed
  empty and the agent ran. `guard-phase` governs nothing a workflow dispatches.
- **A main-loop `Agent` dispatch does reach it**, from
  `~/.claude/plugins/cache/polaris-marketplace/polaris/1.11.0/hooks/guard-phase`, which is the copy
  that runs: edits in this repo are not live until the plugin is updated.
- **`tool_input` carries `description`, `prompt`, `subagent_type`, and `model`, and no effort.** The
  session's effort arrives as a top-level `effort.level`, outside `tool_input`. The `Agent` tool has
  no effort parameter to carry one.

Two consequences, both larger than the task that found them:

1. Task 9's second branch is the real one. A dispatch payload cannot carry the review level, so the
   level has to move through a file under `.polaris/runs/<slug>/` that `guard-phase` reads. AC26
   through AC28 keep their meaning and change their wording, which is a spec amendment.
2. The effort floor already built for R4 reads `.tool_input.effort`, and nothing populates that
   field: workflow dispatches never reach the hook, and a main-loop dispatch has no such field to
   set. The floor is enforced nowhere. `rules/effort-floor.json` and the effort argument each
   workflow now names are still worth their diff, because the workflow sets effort per level at the
   dispatch itself, but the hook half of R4 governs nothing and the report should not claim it does.

## 4. The quality check

Empty. Phase 3 fills this after phase 2's numbers are recorded, per the plan's own phasing: a
configuration is not accepted on the tokens it saves alone.

## What this run cost

The build workflow's Task 4 agent (the sixteen new assertions in `tests/run-tests.sh`) died after
roughly 23 minutes and was retried. The retry started without its predecessor's context: it did not
know what the first agent had already written, and while reproducing the recovery line in
`hooks/enhance-prompt` it replaced `${recorded}` with prose, which silently defeated the requirement
that the recovery line name the artifact rather than describe it. The test the first agent had
already written caught the regression on the next run of the suite. The workflow was stopped by
hand and the line repaired directly.

Two things follow from this, not just for this run. A long single-agent task is a reliability risk
as well as a token cost: the longer a task runs unsupervised, the more expensive its death becomes,
because everything built inside it is at risk of a context-free retry. And a retry without the
original agent's context is not a resume, it is a second attempt that can undo work the first
attempt already got right: here, a named artifact turned into prose that reads similarly but no
longer satisfies the acceptance criterion. This belongs in a report about the cost of orchestration:
the phase 1 numbers above are the saving, and this paragraph is a cost the orchestration itself
incurred while producing them.
