# Recon map — adapt-external-skills

## Destination

For every external skill/plugin the user gathered — the recent.design skills set (~10-12), claude-mem,
and obsidian-second-brain — decide one disposition each: **already-have** (Polaris has equal or better),
**adapt-local** (rewrite the idea into a Polaris agent/skill/command under Polaris's standard),
**companion** (install upstream as-is alongside Polaris), or **skip**. Produce a per-item disposition
table ready to hand to `/flow` to turn adopt/adapt items into specs.

## Notes

Standing preferences, honor in every ticket:

- **Deps decide companion-vs-local.** If a source needs compiled code, npm/Node, a database, or an MCP
  server, it is a **companion** (Polaris stays markdown-and-shell only). Pure prompt/markdown ideas are
  **adapted locally** into Polaris's own standard.
- **Cast wide.** Adopt anything with a good idea, even overlapping ones; the spec stage prunes.
- **Open to replacing** the `ui-new` / `ui-polish` / `ui-prototype` skills if recent.design's design
  skills are clearly better — adapt theirs in and retire ours.
- Licensing bar: Polaris adapts permissively-licensed ideas (MIT/Apache-2.0) with attribution. Flag
  anything not permissive.
- Hard constraint: Polaris is markdown-and-shell only. No compiled code, no package manager, no
  external services inside the plugin.

## Decisions so far

- **recent.design (24 skills / 4 categories)** → mostly **ALREADY-HAVE** (grounded in actual skill
  bodies). Interface 12 = 7 already-have, 4 skip, 1 adapt-local. `quieter`/`distill`/`critique`/`polish`
  are all `pbakaus/impeccable` = Polaris's `ui-polish`. **Adapt:** `arvindrk/extract-design-system`
  (the one clear gap — tokens from a live UI, MIT, but engine is an external npm CLI) and, if motion is
  a priority, the **Motion trio** `apple-design` + `animation-vocabulary` (Polaris's thinnest area).
  **One companion:** `shadcn/shadcn` (needs code/MCP). **Skip:** canvas-design, ui-skills, oklch-skill
  (no license), emil-design-eng (redundant with impeccable). See
  [002-recent-design-skills](adapt-external-skills/002-recent-design-skills.md).
- **claude-mem** → **ADAPT-LOCAL (one idea) + reject wholesale.** Port only the auto-capture-via-hook
  idea (a SessionEnd/Stop hook that writes a markdown session summary + MEMORY.md line). Everything
  else (compact-index-then-fetch, typed memory, timeline/handoff) Polaris already has. Wholesale adopt
  rejected: it needs Node/Bun/Python/Chroma/Redis/HTTP worker/telemetry — the opposite of Polaris's
  zero-dependency axiom. Not recommended as a default companion either (runtime + telemetry contradict
  why users pick Polaris). See [003-claude-mem](adapt-external-skills/003-claude-mem.md).
- **obsidian-second-brain** → **SKIP wholesale/companion + ADAPT-LOCAL two ideas.** Needs Python under
  `uv` (a package manager) plus paid external APIs, and overlaps Polaris memory/journal/docs almost
  entirely. Not blocked by Obsidian (writes plain markdown). Port only two pure-markdown ideas: recency
  markers on facts (`timeless`/`dated`/`pointer`), and a search-before-write reconcile rule for
  `/remember`. See [004-obsidian-second-brain](adapt-external-skills/004-obsidian-second-brain.md).

## Not yet specified

The research frontier is empty; these are the spec-stage items to hand to `/flow`. Graduate any into a
grilling/prototype ticket if a decision is needed before a spec.

Build candidates (adopt/adapt):

- **Memory-quality bundle** (one ticket — all three touch `/remember` + memory + a hook):
  claude-mem auto-capture SessionEnd hook + obsidian recency markers + reconcile-before-write.
  Read `hooks/session-start`, `/track`, `/journal`, `/remember` first to avoid duplication.
- **extract-design-system skill** (recent.design): extract design tokens from a live/public UI into
  Polaris's DESIGN.md token format; feeds `ui-new` and the `ui` agent. Caveat: the engine is an external
  npm CLI + Playwright, so the local skill is only a thin wrapper — decide if the npm dependency is
  acceptable (per deps-decide rule this leans companion-ish).
- **Motion skill/baseline** (recent.design): adapt `apple-design` + `animation-vocabulary` (the Motion
  trio, MIT) under Polaris's "animate transform/opacity only" rule. Decide: standalone skill vs fold
  into `ui` baseline. (emil-design-eng is redundant — do not use as the source.)

Open decisions (need a call before spec):

- **shadcn companion:** wire into `scripts/ensure-companions.sh` or just document as a pointer? (grilling)
- **Skill-name discrepancy (verify first):** ticket 002 cites `ui-ux-pro-max`, `frontend-design`,
  `design-taste-frontend`, `accessibility-a11y`, `impeccable`, `animate` — only `ui-polish`/`ui-new`/
  `ui-prototype` exist in `skills/`. Confirm what the `ui` agent actually wires before trusting the
  "already-have" claims for the rules-manual/defaults/a11y entries. (task — read `agents/ui.md`)

## Out of scope

- Actually building the adaptations — that is `/flow`'s job after this map clears.
- Adopting sources not in the three the user named.
- Changing Polaris's markdown-and-shell-only constraint to accommodate a heavy plugin.
