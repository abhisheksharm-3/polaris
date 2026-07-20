# 001 — Decision criteria for adopt vs companion vs local

- type: grilling (HITL)
- blocked-by: []
- status: closed

## Question

How should each source be judged: what makes something a companion vs a local adaptation, how wide
do we cast, and how do we treat overlap with Polaris's existing UI/UX layer?

## Answer (from the human)

1. **Deps decide companion-vs-local.** Needs compiled code / npm / DB / MCP server → COMPANION.
   Pure prompt/markdown that fits Polaris's standard → ADAPT-LOCAL.
2. **Cast wide.** Adopt anything interesting, even overlapping; prune at the spec stage.
3. **Open to replacing** `ui-new` / `ui-polish` / `ui-prototype` if recent.design's are clearly better.
