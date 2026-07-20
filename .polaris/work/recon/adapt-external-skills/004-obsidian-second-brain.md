# 004 — obsidian-second-brain (eugeniughelbur/obsidian-second-brain)

- type: research (AFK)
- blocked-by: []
- status: closed

## Question

Should Polaris adopt obsidian-second-brain — wholesale, as a companion, or by porting ideas?

## Answer

**SKIP wholesale / as companion + ADAPT-LOCAL two narrow ideas.** License MIT (clean for porting).

- **What it is:** a cross-CLI markdown "second brain" — a vault (`raw/`, `wiki/`, `boards/`) plus
  operating files (`SOUL.md` identity, `CRITICAL_FACTS.md` always-loaded core, `log.md`, `index.md`),
  45 commands, self-rewriting ingest, a context engine, and a research toolkit.
- **Not blocked by Obsidian** — it writes plain markdown; the app is an optional viewer. The real
  disqualifier is the stack: **Python (587 KB) under `uv` (a package manager)** for its maintenance
  engine (`vault_health.py`, `bootstrap_vault.py`, `link_graph.py`, etc.) and **paid external APIs**
  (xAI/Grok, Perplexity, Gemini, OpenAI) for research. Three hard-constraint violations → cannot bundle
  or endorse as a companion. It also overlaps Polaris memory + journal + docs almost entirely
  (ALREADY-HAVE), so running both means two parallel note stores.
- **Port only these two (pure markdown/shell, no Python, no Obsidian):**
  1. **Recency markers on memory facts** — tag each fact (or external claim) `timeless` /
     `dated (YYYY-MM-DD)` / `pointer-to-live-source`. Polaris has no freshness convention; add it as
     frontmatter + a small `check-patterns`-style shell lint. Stops stale facts rotting in memory.
  2. **Search-before-write / reconcile rule for `/remember`** — search exhaustively for an existing
     note and update in place rather than creating a duplicate. Prompt-only addition. Prevents
     near-duplicate fact files. (Note: Polaris's `/remember` already has a "check for existing file"
     rule — this would strengthen it, verify before treating as net-new.)
- **Do NOT port:** `CRITICAL_FACTS.md` always-loaded core (Polaris already injects MEMORY.md +
  writing standard at session-start); the Python lint scripts as-is.

## Follow-on

Promotes at most a small "memory-quality pass" build ticket (recency markers + reconcile rule),
only if a memory pass is wanted. Both ideas overlap the same `/remember` + memory surface as 003's
auto-capture hook — bundle them into one memory ticket for `/flow`.
