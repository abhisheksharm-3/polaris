---
description: A timeboxed throwaway prototype to answer a feasibility question, then discard or graduate it
argument-hint: "<the question to answer>"
allowed-tools: Task, Read, Bash, Grep, Glob, Edit, Write, WebFetch, WebSearch
---

# Spike

Answer the feasibility question in `$ARGUMENTS` with the smallest throwaway prototype that settles
it. A spike buys knowledge, not code that ships. Read `.polaris/config.json` first.

## Steps

1. **Frame the question.** State exactly what the spike must answer and what a yes or a no looks
   like. "Can we stream this API's responses within our latency budget?" beats "try streaming".
2. **Isolate.** Work in a git worktree so the throwaway code never touches the real branch. The
   spike is not held to the full quality bar, because it is not going to ship; say so.
3. **Build the minimum that answers it.** Ground in the code and fetch fresh docs via the docs
   protocol. Prototype only the part that resolves the unknown; stub everything else. Ponytail
   applies harder here, not less: the spike is the one-liner that proves the point.
4. **Answer.** Run it, observe, and answer the question with evidence: what worked, what did not,
   the numbers, and the risks a real build would face.
5. **Discard or graduate.** Delete the worktree by default. If the answer is yes and the approach is
   sound, write the findings to `.polaris/reports/<date>-spike-<topic>-report.md` and hand off to
   `/flow` to build it properly. Never promote spike code straight to production.

## Rules

- The deliverable is the answer, not the prototype. Do not polish throwaway code.
- Keep the spike isolated so it cannot leak into a real branch.
