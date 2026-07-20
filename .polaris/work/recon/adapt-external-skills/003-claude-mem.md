# 003 — claude-mem (thedotmack/claude-mem)

- type: research (AFK)
- blocked-by: []
- status: closed

## Question

Should Polaris adopt claude-mem — wholesale, as a companion, or by porting ideas?

## Answer

**ADAPT-LOCAL (one idea) + reject wholesale + not a default companion.** License Apache-2.0 (clean).

- **What it is:** automatic memory compression for Claude Code. Captures tool-usage observations via
  5 lifecycle hooks, stores in SQLite + Chroma vector DB, retrieves via 4 MCP tools with a
  compact-index-then-fetch-detail flow and a React web viewer.
- **Architecture clash:** needs Node ≥20, Bun, Python (uv), SQLite, Chroma, a long-running Express
  worker, React UI, optional Redis/Postgres, and PostHog telemetry. That is the opposite of Polaris's
  markdown-and-shell, zero-dependency, no-service axiom. Wholesale bundling is impossible; as a
  companion it does not technically break Polaris (separate process) but its runtime + telemetry
  contradict why users pick Polaris — so **not recommended as a default companion**.
- **ALREADY-HAVE:** the compact-index-then-fetch pattern (MEMORY.md pointer → per-fact file), typed
  memory (frontmatter types), and timeline/where-you-left-off (`/journal`, `/catchup`, `/handoff`,
  `/track`).
- **Port only this:** **automatic session capture via a hook.** A SessionEnd/Stop hook that writes an
  auto-generated markdown session summary (an observation file + a MEMORY.md index line) using shell +
  the in-loop model. Closes Polaris's real gap (manual-only capture) with no runtime. **Do NOT** try to
  clone the semantic vector search — not doable in markdown/shell; Polaris retrieval stays lexical.

## Follow-on

Promotes a build ticket: "auto-capture session-summary hook" — read `hooks/session-start` and the
`/track` + `/journal` definitions first to avoid duplicating them.
