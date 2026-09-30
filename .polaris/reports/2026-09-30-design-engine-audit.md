# Design engine audit

Date: 2026-09-30. Run: audit-0930. Scope: every agent, flow, workflow, rule, route, and companion
that touches visual or interaction design, plus five external sources proposed for adoption.

## Verdict

Polaris has design *agents* but no design *engine*. The `ui` agent is dispatched only when the
build Split happens to name it, the `ux` agent is dispatched only as the accessibility reviewer,
no flow has a visual-design phase, nothing reads a design contract, and nobody looks at the
rendered result. Design quality is left to whatever five preloaded skills the `ui` agent reconciles
on its own, and those skills contradict each other.

## Findings by severity

### High

- **H1. No design phase in any flow.** `rules/flows.json` `feature.design` runs `agent:architect`,
  which designs system structure (components, seams, ADRs). No flow runs `agent:ux`, and none runs
  design direction, visual critique, or iteration. UI goes straight from spec to `workflow:build`.
- **H2. Design prompts route nowhere.** `scripts/route-prompt.sh`: "make the landing page look less
  generic", "redesign the dashboard", "polish the UI of the pricing page" all return `unknown`.
  "the app looks ugly, fix the design" returns `fix` (single-file, no critique). "create a design
  system" returns `feature` (spec, then architect).
- **H3. No one sees the output.** `agents/ui.md`, `agents/tester.md`, `workflows/build.js`, and
  `workflows/verify.js` never require a screenshot. The `ui` agent has the Chrome tools but no step
  uses them. The build Check stage for a UI slice is a code reviewer and a behavior tester; neither
  judges hierarchy, spacing, type, or whether it looks templated.
- **H4. No design contract.** Nothing reads a `DESIGN.md`. `skills/extract-design-system` writes
  one and hands it to "the ui agent", which has no instruction to look for it. Every UI slice
  re-decides palette, type, and spacing from scratch, so two slices of one feature drift.
- **H5. Licensing.** `huashu-design` is preloaded by `agents/ui.md` and named in
  `companions.json` `namedSkills.ui`. Its LICENSE is "Huashu Design · Personal Use License" with
  paid commercial terms. Polaris is used for client work at Wednesday.

### Medium

- **M1. Preload cost and conflict.** `agents/ui.md` preloads five skills: huashu-design 60.6 KB,
  ui-ux-pro-max 44.8 KB, design-taste-frontend 21.1 KB, impeccable 14.1 KB, frontend-design 9.4 KB.
  That is about 150 KB, roughly 37k tokens, on every `ui` dispatch, before the agent reads a file.
  They disagree: taste prescribes Geist/Outfit and high variance, impeccable and frontend-design say
  choose with intent, huashu is an HTML-prototype and video tool. Rule 7 says pick one; the agent is
  left to average them.
- **M2. Stale companion.** The local `design-taste-frontend` is upstream v1 (21 KB). Upstream v2
  (87 KB) is the current default. Installed via `npx skills` symlinks, not a pinned source.
- **M3. Duplicated, contradictory baseline.** The design baseline lives in both `agents/ui.md` and
  `rules/stacks/react.md` with different content. `react.md` prescribes "Geist, Outfit, or Cabinet
  Grotesk", which contradicts `ui.md`'s "choose a typeface with intent" and any project DESIGN.md.
  The baseline only reaches React projects; a Vue, Svelte, or plain HTML project gets nothing.
- **M4. Review has no design dimension.** `workflows/review.js` has `accessibility` (via `ux`) but
  nothing for interaction and visual quality: focus management, form behavior, `transition: all`,
  layout shift, tabular numbers, the checklist Vercel publishes. A UI diff passes review on
  correctness alone.
- **M5. Deterministic UI smells are left to judgment.** `transition: all`, `user-scalable=no`,
  `outline-none` with no replacement, `onPaste` + `preventDefault`, `<div onClick>`, `100vh`,
  `<img>` without dimensions are all greppable. `rules/patterns.json` has no `ui` class (Rule 5).
- **M6. Model tier.** `ui` and `ux` run at sonnet/medium (`rules/model-floor.json`,
  `rules/effort-floor.json`) while `api-designer` runs at opus/high. Visual judgment is where the
  tier shows most.

### Low

- **L1.** `inject-standard` gives the `ui` agent the comment law and the ladder but no design rule.
- **L2.** `skills/extract-design-system` is the only design skill Polaris owns, and it is unreachable
  from any flow.
- **L3.** `feature-builder` writes UI components (step 2f) with no design skill and no baseline.

## External sources

| Source | License | Shape | Decision |
|---|---|---|---|
| voltagent/awesome-design-md | MIT | 74 brand `DESIGN.md` files (Google Stitch format), `npx getdesign add <slug>` CLI | **Adapt the format.** DESIGN.md becomes Polaris's design contract. Do not vendor 2 MB of brand files; call `npx getdesign` when the user wants a reference brand |
| vercel.com/design/guidelines | MIT (vercel-labs/web-interface-guidelines) | `command.md`, 7.7 KB, ~100 rules in 17 groups | **Adapt: vendor pinned.** Becomes the interface checklist the design review and the `ui` agent hold to |
| vercel-labs/agent-skills web-design-guidelines | no LICENSE file, README says MIT | 1.2 KB wrapper that WebFetches `command.md` every run | **Skip.** It is only a fetch of the file above; vendoring removes the network dependency |
| taste-skill image-to-code | MIT | 36 KB, image generation first, written for Codex | **Adapt the half that works.** Claude Code has no image generation, but it reads images. Keep screenshot/mockup to code with an anti-drift render-and-compare loop; drop the generate step |
| Leonxlnx/taste-skill | MIT | Claude Code plugin, 13 skills, many overlapping | **Companion plugin, not preloaded.** Installing it pins v2 and replaces the stale npx copy. Polaris distills the core (three dials, the AI-tells ban list) into its own rule so no agent preloads 87 KB |

## Proposed rework

1. **One design standard.** New `rules/design.md`: the baseline (merged from `ui.md` and
   `react.md`, contradictions removed), the taste dials and AI-tells list, the DESIGN.md contract.
   New `rules/design-interface.md`: Vercel `command.md`, vendored, pinned, attributed.
   `react.md` keeps only React-specific motion mechanics and points at `rules/design.md`.
2. **DESIGN.md is the contract.** Every UI-writing agent reads the project root `DESIGN.md` first.
   If it is missing, the direction phase writes one: from a reference brand (`npx getdesign add`),
   from a live site (`extract-design-system`), or from the brief.
3. **A `design` flow** in `rules/flows.json`: `direction` (ux: DESIGN.md plus flow and states,
   approve) → `build` (ui) → `critique` (screenshots at 375, 768, 1440 and dark mode, judged against
   DESIGN.md, the interface rules, and the AI-tells list) → `gate`. Routing patterns send redesign,
   polish, restyle, "looks generic", mockup, screenshot, and design-system prompts to it.
4. **Build and review see the pixels.** `workflows/build.js`: a slice built by `ui` gets a visual
   critique check beside the reviewer and tester. `workflows/review.js`: a `design` dimension,
   selected when the diff touches UI files, holding the interface rules.
5. **Deterministic UI patterns.** A `ui` class in `rules/patterns.json` for M5's list, run by
   `check-patterns.sh` and the gate.
6. **Agents.** `ui` preloads `frontend-design` only (9 KB) and loads the rest on demand by task:
   `impeccable` for critique and polish, `ui-ux-pro-max` for palette and font lookup, taste presets
   for a named style. `huashu-design` is removed. `ux` owns design direction and DESIGN.md.
   `tester` screenshots UI at the three widths. `inject-standard` adds the design summary for `ui`.
   `feature-builder` defers UI components to `ui`.
7. **New skill `image-to-code`** (Polaris-owned, adapted from taste-skill, MIT attribution): a
   user-supplied image to code, then render, screenshot, compare, and fix until it matches.
8. **Companions.** Add taste-skill as a marketplace plugin. Drop huashu-design from
   `namedSkills.ui` and `companionSkills`.
9. **Tests.** Suite asserts: the design flow resolves (`check-flows.sh`), the routing fixtures above
   land on `design`, the `ui` pattern class flags each fixture, `ui.md` preloads no skill over a
   byte ceiling, and no Personal Use skill is named.

## Open decisions

- Model tier for `ui` and `ux` (M6): sonnet/medium today.
- Whether to install taste-skill as a plugin (adds 13 skill descriptions to every session) or keep
  only the distilled rule.
