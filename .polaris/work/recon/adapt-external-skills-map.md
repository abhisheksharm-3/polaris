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

## Status — all items resolved (2026-07-20)

Everything charted has been built, decided, or deliberately skipped. Commits on `main`:

- **Memory-quality bundle** → **SHIPPED** `ad45f36`. Scope collapsed after discovery: auto-capture and
  reconcile were already-have, so built only freshness markers (`timeless`/`dated`/`pointer`) + a
  reconcile-by-body tweak to `/remember`. No SessionEnd hook.
- **extract-design-system** → **SHIPPED** `46f60a7`. Thin local skill over the `npx` engine, mapping to
  DESIGN.md. npm engine stays external, invoked on demand.
- **Motion** → **SHIPPED** `46f60a7`. Folded `apple-design` + `animation-vocabulary` into the ui
  baseline (`rules/stacks/react.md` + `agents/ui.md`), not a competing skill.
- **shadcn** → **SHIPPED** `46f60a7`. Declared in `companions.json` as an optional companion, not
  auto-installed.
- **ui.md wiring verification** → **DONE** `9d839f3`. Already-have claims hold; recorded in ticket 002.
- **check-commands.sh skills-token validation** → **SHIPPED** `fcac4b8`. Validates each agent `skills:`
  token resolves to a local skill/command or a declared companion; `companions.json .companionSkills`
  is the source of truth.
- **Rename `ui-polish`→`impeccable`** → **SKIPPED (decided).** `skills/ui-new` invokes `polaris:ui-polish`
  by name, so the rename would break the ui-new pipeline; the drift it would fix is already handled by
  the check + the `companions.json` declaration. Not worth the churn. Possible future cleanup: dedupe the
  locally-bundled impeccable (`ui-polish`) against the companion `impeccable` the ui agent wires.

## Out of scope

- Actually building the adaptations — that is `/flow`'s job after this map clears.
- Adopting sources not in the three the user named.
- Changing Polaris's markdown-and-shell-only constraint to accommodate a heavy plugin.
