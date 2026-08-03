---
description: Build a flow for a task no catalog row fits, from the agents and commands installed
argument-hint: "<the task, as the user described it>"
allowed-tools: Bash, Read, Grep, Glob
model: opus
---

# Compose a flow

Build the sequence that completes the task in `$ARGUMENTS`, using what Polaris already has. The
catalog in `rules/flows.json` holds the shapes that recur; this is for everything else, which is
most work.

`/synthesize` is the sibling on the other axis: it composes an agent when no fleet agent fits. This
composes a sequence when no flow fits. If the task needs both, name `command:synthesize` as a phase.

## Steps

1. **Read the inventory.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/inventory.sh`. It prints every target
   a phase may name, with a description. Choose only from that list. A phase naming anything else
   is refused at seed time, so inventing a target wastes the turn.
2. **Check the catalog first.** Run
   `jq -r 'to_entries[] | "\(.key): \([.value.phases[].name] | join(" -> "))"' "${CLAUDE_PLUGIN_ROOT}/rules/flows.json"`.
   If a row fits, use it: `scripts/run-state.sh seed <flow> <slug>` and stop. Composing over a row
   that already fits is how a catalog stops meaning anything.
3. **Compose the smallest sequence that finishes the work.** The laziness ladder applies to
   sequences as much as to code. A phase that earns nothing is over-engineering on a new axis, and
   it costs a real dispatch every time the flow runs. Three phases that each change something beat
   six that look thorough.
4. **Mark what a human must see.** Put `"approve": true` on a phase whose output the user should
   read before the next one starts: anything that commits to a direction, spends real money, or
   is expensive to undo. Not on every phase; an approval on all of them is the same as none.
5. **State the evidence.** Give a phase an `evidence` string naming what it must produce, and the
   ledger will refuse to record it without an artifact on disk. Leave `evidence` off a phase that
   produces no file, or the run cannot advance past it.
6. **Seed it.** Pipe the phase array to
   `scripts/run-state.sh seed --composed <slug>`, deriving the slug from the task.
7. **Announce it, then run the first phase.** Print the phases in order and say which ones stop for
   approval. If the shape is wrong, the user says so now, not at phase four.

## The shape

```json
[
  { "name": "survey", "run": "agent:researcher", "evidence": "what exists today" },
  { "name": "change", "run": "specialist" },
  { "name": "check",  "run": "command:gate", "evidence": "gate output" }
]
```

`run` is `agent:<name>`, `command:<name>`, `workflow:<name>`, `inline` for a phase you do yourself,
or `specialist` for the fleet agent that fits, chosen when the phase runs.

## Rules

- Never name a target the inventory did not print.
- Never compose for a question. A question is answered, not run.
- Never compose a phase list longer than the task earns.
- Say what you chose and why in one line per phase, then stop for the user's word.
