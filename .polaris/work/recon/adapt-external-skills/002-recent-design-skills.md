# 002 — recent.design skills

- type: research (AFK)
- blocked-by: []
- status: closed

## Question

For each skill on recent.design, is Polaris's version equal/superior (already-have), worth adapting
locally, better as a companion, or skip?

## Answer

Site has **24 skills in 4 categories** (Interface 12, Development 8, Motion 3, Research 1), not 10-12.
The recent.design slugs are not 1:1 GitHub repos: `quieter` / `distill` / `critique` / `polish` all
resolve to **`pbakaus/impeccable`**, which Polaris already ships as `ui-polish` (verified in-repo).

Dispositions below are grounded in the actual SKILL.md/README bodies (second verification pass),
which supersedes the first blurb-based pass. Reading the bodies made it MORE skeptical.

Monorepo aliases (not 1:1 repos): `quieter/distill/critique/polish` = `pbakaus/impeccable`;
`canvas-design` + `frontend-design` = `anthropics/skills`; `web-design-guidelines` = `vercel-labs/agent-skills`;
Motion trio = `emilkowalski/skill`.

### Interface (12) — 7 already-have, 4 skip, 1 adapt-local, 0 companion

| Skill | License | Disposition | Reason |
|---|---|---|---|
| anthropics/canvas-design | Apache-2.0 | SKIP | Static art/poster (PNG/PDF) generation, not UI-for-software; outside SDLC scope |
| pbakaus/quieter | Apache-2.0 | ALREADY-HAVE | `impeccable/reference/quieter.md` = ui-polish command |
| pbakaus/distill | Apache-2.0 | ALREADY-HAVE | same `impeccable` repo |
| pbakaus/critique | Apache-2.0 | ALREADY-HAVE | ui-polish command (37KB, sophisticated; Polaris has the strong version) |
| pbakaus/polish | Apache-2.0 | ALREADY-HAVE | namesake of ui-polish |
| vercel-labs/web-design-guidelines | MIT | ALREADY-HAVE | 1.2KB wrapper that WebFetches Vercel's guidelines; audit+a11y already covered. *If you want Vercel's live ruleset specifically → COMPANION (it self-fetches latest, forking freezes it)* |
| ibelick/ui-skills | MIT | SKIP | A suite of 6 sub-skills + `npx` router; each duplicates Polaris ui/ux/a11y/perf routing |
| emilkowalski/emil-design-eng | MIT | **SKIP** | 27KB taste/animation philosophy; impeccable already ships `animate`/`interaction-design`/`craft`/`delight`. Motion edge better sourced from the Motion trio |
| jakubkrehel/make-interfaces-feel-better | MIT | ALREADY-HAVE | micro-craft rules = impeccable's job. *Cherry-pick: concentric-radius / optical-alignment rules worth lifting into ui baseline if not already there* |
| raphaelsalaja/userinterface-wiki | MIT | ALREADY-HAVE | 152-rule DB, parallel to ui-new's rule DB; net-new subset = motion/cognitive-law rules (folds into Motion decision) |
| jakubkrehel/oklch-skill | **NONE (all rights reserved)** | SKIP | Most technically novel (OKLCH perceptual palettes, APCA/WCAG, P3) but **no license = cannot fork**; author fresh (OKLCH is a public standard) if wanted |
| arvindrk/extract-design-system | MIT | **ADAPT-LOCAL** | **The one clear net-new capability.** BUT the engine is an **npm CLI** (`npx extract-design-system <url>` + Playwright) — even "local" is a thin skill-wrapper over an external npm dependency. Maps output into DESIGN.md tokens, feeds ui-new |

### Other categories

- **Motion (3, `emilkowalski/skill`, MIT):** `apple-design` + `animation-vocabulary` = **ADAPT-LOCAL**
  (motion is Polaris's thinnest area — ui baseline is one line + impeccable's single `animate` ref);
  `review-animations` = ALREADY-HAVE (borderline; overlaps impeccable `animate` + reviewer agent).
  This trio is the better motion source than emil-design-eng.
- **Development (8):** `anthropics/frontend-design` ALREADY-HAVE; `shadcn/shadcn` = **COMPANION**
  (component CLI/registry + MCP, not a ruleset — needs code); `vercel-labs/agent-browser` ALREADY-HAVE
  (playwright-e2e + e2e agent + claude-in-chrome MCP); Vercel React/RN/composition +
  `typescript-advanced-types` + `tailwind-design-system` map to `rules/stacks/` overlays.
- **Research (1):** `mattpocock/grill-me` — Socratic decision-grilling; ALREADY-HAVE (overlaps `product`
  agent ambiguity loop, `/recon`, brainstorming). Not UI.
- **Nav galleries** (Design / Websites / OG Images / App Screenshots / App Icons / Tools) are curation
  galleries, not installable skills. Only `/skills` is installable content.

### Flags / low-confidence

- **License:** `oklch-skill` has no license (all rights reserved) — do not copy.
- **extract-design-system needs npm** — flag against the deps-decide rule: it's adapt-local only as a
  thin wrapper; the extraction engine stays an external npm/Playwright dependency either way.
- **Skill-name discrepancy (verify):** ticket cites `ui-ux-pro-max`, `frontend-design`,
  `design-taste-frontend`, `accessibility-a11y`, `impeccable`, `animate` — only `ui-polish`/`ui-new`/
  `ui-prototype` are in `skills/`. Confirm what `agents/ui.md` actually wires before trusting the
  "already-have" claims for the audit/rules/a11y overlaps.
- Per-skill licenses inside the `wshobson/*` and `mattpocock/skills` monorepos not confirmed at file
  level (permissive by convention). Gallery pages not opened to prove zero installable skills.

## Follow-on

Promotes build tickets: (1) extract-design-system adaptation, (2) a motion skill from the 3 emil
motion skills, (3) shadcn companion decision (wire vs document). Plus a verification task on the
skill-name discrepancy above.
