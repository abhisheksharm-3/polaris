---
description: Open the design flow on a UI task and run its direction phase
argument-hint: "<what to design, redesign, or polish; a reference brand, URL, or screenshot>"
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
model: sonnet
---

# Design

Open the `design` run for the task in `$ARGUMENTS` and start it. This is the design counterpart of
`/polaris:flow`: the flow is the `design` row in `rules/flows.json`, and the ledger and the gates
enforce it. `hooks/enhance-prompt` opens the same run for a described redesign, polish, mockup, or
design-system task, so this command is the explicit door to the same room.

## Steps

1. Read `.polaris/config.json`.
2. Open the run: `${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh seed design <slug>`, with a slug drawn
   from the task. It refuses when this session already has a run open; `/polaris:pause` clears it.
3. Say which phases the run holds and which stop for approval:
   `jq -r '.design.phases[] | "\(.name) -> \(.run)"' "${CLAUDE_PLUGIN_ROOT}/rules/flows.json"`.
4. Run the first phase. Dispatch `ux` in direction mode with the task and anything the user gave:
   a reference brand for `npx getdesign@latest add <slug>`, a URL for `extract-design-system`, a
   screenshot or mockup path for the ui agent's `mockup-to-code` skill later. It writes or extends
   `DESIGN.md` and the UX spec.
5. Record it: `scripts/run-state.sh record direction DESIGN.md "<the design read and dials>"`.
6. Present the design read, the dials, and what `DESIGN.md` now holds, and stop. `direction`
   carries an approval, so the run holds until a human says go and
   `scripts/run-state.sh approve direction` runs.

From there `advance-flow` names each phase: `ui` builds and renders, `ux` critiques from
screenshots, `ui` polishes each finding, and the gate runs with its ui pattern class.

## Rules

- The flow is the data in `rules/flows.json`. If this file and that one disagree, that one is right.
- Approval phases are hard stops. Never stamp an approval on the human's behalf.
- A phase that could not render the UI says so in its evidence. An unrendered design is unverified.
