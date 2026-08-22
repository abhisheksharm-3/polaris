---
description: Abandon the open Polaris run so the next prompt routes freshly
allowed-tools: Bash, Read
model: haiku
---

# Pause the open run

Clear the run the router opened, so the phase gate stops refusing dispatches against it and the
next prompt is classified from scratch.

Run `${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh clear`. It prints the slug it cleared, or exits
non-zero saying no run is open. It clears this session's run only; a run open in another session
keeps going.

Then say in one line what was cleared and which phase it was on, so the work is not lost silently.
If the run was cleared because the flow was wrong for the task, say which flow would have fit; that
is the misroute worth knowing about.

Do not delete anything the run produced. Clearing a run drops the ledger, not the spec, the
reproduction, or the report the phases wrote.
