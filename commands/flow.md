---
description: Open the feature flow on a task and run its first phase
argument-hint: "<task, PRD, or idea>"
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

# Flow

Open the `feature` run for the task in `$ARGUMENTS` and start it.

This command used to hold the cycle itself: eleven phases of prose a model was free to abridge and
nothing checked. The cycle is now the `feature` row in `rules/flows.json`, and the ledger and the
gates enforce it. Two descriptions of one flow is one too many, so this is the shorter one.

You do not need to type this. `hooks/enhance-prompt` classifies a described feature and opens the
same run. This is the explicit door to the same room.

## Steps

1. Read `.polaris/config.json`.
2. Open the run: `${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh seed feature <slug>`, with a slug drawn
   from the task. It refuses when this session already has a run open; `/polaris:pause` clears
   that one. Another session's run is no obstacle, and a slug it already owns is.
3. Say which phases the run holds and which stop for approval:
   `jq -r '.feature.phases[] | "\(.name) -> \(.run)"' "${CLAUDE_PLUGIN_ROOT}/rules/flows.json"`.
4. Run the first phase. Dispatch `product` to write the spec, with explicit acceptance criteria,
   into `.polaris/specs/`.
5. Record it: `scripts/run-state.sh record spec <path> "<what the check said>"`. The ledger refuses
   a phase whose artifact is not on disk, and stores the hash, so an artifact edited afterwards
   invalidates the phase that claimed it.
6. Present the spec and stop. `spec` carries an approval, so the run holds here until a human says
   go and `scripts/run-state.sh approve spec` runs.

From there the hooks drive it. At the end of each turn `advance-flow` names the next phase.
`guard-phase` refuses an agent the current phase does not name, and `guard-command` refuses a phase
command whose predecessor has not been earned.

## Rules

- The flow is the data in `rules/flows.json`. If this file and that file disagree, that file is
  right and this one is the bug.
- Approval phases are hard stops. Never stamp an approval on the human's behalf.
- Nothing outward-facing happens without confirmation unless the config authorizes it.
- Evidence before claims: run the command, show the output, and record it in the ledger.
