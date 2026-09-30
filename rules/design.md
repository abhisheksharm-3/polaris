# Polaris design standard

<!-- The one design rule every UI-touching agent reads: ux, ui, the critique step, and the design -->
<!-- review dimension. Framework-agnostic; rules/stacks/react.md holds only React mechanics. The -->
<!-- dials, the AI-tells list, and the redesign protocol are distilled from Leonxlnx/taste-skill -->
<!-- (MIT). The DESIGN.md contract is the Google Stitch format that voltagent/awesome-design-md -->
<!-- (MIT) collects. The interface checklist is rules/design-interface.md, vendored from Vercel. -->

## Authority

When two sources disagree, the higher one wins and the lower one is not averaged in:

1. The project's `DESIGN.md` at the repo root.
2. The user's brief for this task.
3. This file and `rules/design-interface.md`.
4. A companion skill (taste presets, impeccable, ui-ux-pro-max, frontend-design).

Say which source decided a contested choice in one line, so a reviewer can check it.

## The design read

Before any markup, write one line: "Reading this as: <page kind> for <audience>, in a <vibe>
language, leaning toward <design system or aesthetic family>." Page kind, the user's vibe words,
references they linked or pasted, the audience, existing brand assets, and quiet constraints
(public sector, regulated, accessibility-first, children) decide it. Quiet constraints override
taste. If two reads are genuinely open, ask one question; otherwise declare the read and proceed.

## The three dials

Set them after the read and record them in `DESIGN.md`. Every layout, motion, and density choice
follows from them.

| Dial | 1-3 | 4-7 | 8-10 |
|---|---|---|---|
| `VARIANCE` | symmetric grid, centered, equal padding | offsets, varied aspect ratios, left-aligned heads | asymmetric grids, large empty zones |
| `MOTION` | hover and active states only | CSS transitions and staggered entry on transform and opacity | scroll-driven choreography, never a `scroll` listener |
| `DENSITY` | gallery: `py-32` sections | app: `py-16` to `py-24` | cockpit: tight, 1px dividers, no cards, tabular numbers |

Starting points: SaaS landing 7/6/4, agency or creative 9/8/3, premium consumer 7/6/3, editorial
6/4/3, product app or dashboard 4/3/7, public-sector service 3/2/5. A redesign that preserves the
brand reads the existing site's dials and moves motion at most one step. At variance 4 and above,
every asymmetric layout collapses to one column under 768px, declared in the same component.

## DESIGN.md is the contract

The repo-root `DESIGN.md` is the project's design system in the Stitch format: YAML frontmatter
(`name`, `description`, token maps for `colors`, `typography`, `rounded`, `spacing`, `components`),
then sections for visual theme, colors by role, typography scale, layout and spacing, elevation,
shapes, components with their states, do's and don'ts, responsive behavior, and an agent prompt
guide. Polaris adds one section, `## Dials`, holding the three values and the design read.

- **Read it first.** Every agent that writes or judges UI reads `DESIGN.md` before anything else.
  A value in the code that is not in `DESIGN.md` is a token to add there, not a one-off.
- **When it is missing, the direction phase writes it,** from one of three seeds: a reference brand
  (`npx getdesign@latest add <slug>`, 70+ brands such as linear, stripe, vercel, notion; the user
  names it or picks from `npx getdesign@latest list`), a live site the user is entitled to reference
  (the `extract-design-system` skill), or the brief alone. A brand seed is a starting point to
  adapt, never a clone: change the name, the accent, and one signature element.
- **Existing code is evidence.** On a redesign, derive the current tokens from the code before
  proposing new ones; the codebase's existing theme file outranks a seed.

## Baseline

- **Type.** A typeface chosen for this product, recorded in `DESIGN.md`. Inter or the system stack
  as an unexamined default is the tell, not Inter itself; a neutral, public-sector, or
  Linear-style read may pick it on purpose. Serif display only when the brand or an editorial read
  justifies it, never on dense data UI. One family carries emphasis through weight and italic;
  do not inject a second family for one word. Body copy caps at about 65ch.
- **Color.** Neutrals from one temperature, one accent, used everywhere on the page. No AI-purple
  or blue-to-violet wash unless the brand is purple. No pure `#000` or `#fff`. Shadows tinted to
  the surface. Contrast meets WCAG AA in both themes, and hover, focus, and active raise contrast.
- **Shape and depth.** One radius scale, or a written rule per component kind, followed everywhere.
  A card exists only when elevation means hierarchy; otherwise group with space or a divider.
- **Layout.** `min-h-[100dvh]`, never `100vh`. The hero fits the first viewport: headline at most
  two lines, supporting copy at most about 20 words, the primary action visible. Navigation stays
  one line at 1024px. No layout family repeats on a page, and no more than two image-text zigzags
  in a row. A grid has as many cells as there is content.
- **States.** Loading as a skeleton shaped like the content, empty that teaches the next step,
  error that says what happened and how to recover, disabled that is inert, success that confirms.
- **Motion.** It shows cause and effect or spatial continuity, or it goes. Animate `transform` and
  `opacity` only, never `transition: all`. About 150-250ms for feedback, 300-500ms to enter or
  leave, longer for larger elements; ease-out entering, ease-in leaving, never linear. Start from
  where the interaction happened, stagger lists 20-40ms, stay interruptible, and honor
  `prefers-reduced-motion`.
- **Imagery and icons.** Real photographs or honest placeholders, never a product UI faked from
  styled divs. One real icon set, never emoji as icons, never hand-drawn SVG icons.
- **Themes.** Dual theme unless the brief says otherwise, with `color-scheme` set. Hierarchy that
  works in light works in dark. Look at both before calling it done.

## AI tells

Each one is the signature of a design nobody decided on. The critique step and the design review
flag them unless `DESIGN.md` or the brief asks for one.

- A centered hero over a dark gradient mesh, three equal feature cards, glassmorphism everywhere.
- Gradient text on large headings, neon glows, oversaturated accents.
- An eyebrow label above every section. At most one per three sections.
- Section numbering as decoration (`01 / Capabilities`), `01 / 4` pagination on tiles, version
  stamps (`v0.6`, `BETA`) in a marketing hero, decorative status dots, scroll cues.
- A left headline with a small floating explainer paragraph in the right column, by default.
- The same call to action worded three ways. One label per intent, used everywhere.
- A call-to-action label that wraps at desktop width.
- Filler names and numbers: John Doe, Acme, `99.99%`, `1234567`. Filler verbs: elevate, unleash,
  seamless, next-gen. Copy passes `rules/writing.md`, including its em-dash discipline.
- An unstyled component-library default shipped as the look.

## Redesign

Classify first: preserve (modernize inside the brand) or overhaul (new visual language on the same
content). Ask once if it is unclear. Audit before touching: tokens, information architecture,
content that works, patterns to keep, tells to retire. Pull levers in order and stop when the brief
is met: type, spacing and rhythm, color, motion, recomposing key sections, replacing a block. Never
change silently: URLs and slugs, primary navigation labels, form field names and order (analytics
and autofill depend on them), the logo, and legal or consent copy.

## Seeing the result

Code that compiles is not a design that works. Before UI work is done, it is rendered and looked at:

1. Start the app (or open the static file) and capture screenshots at 375, 768, and 1440 px wide,
   in light and in dark where the product has both. Use the Chrome tools or Playwright, whichever
   the session has.
2. Judge each screenshot against `DESIGN.md`, the baseline, the AI tells, and
   `rules/design-interface.md`: hierarchy (one primary action per view), spacing rhythm, alignment,
   type scale, contrast, overflow and truncation, and every state the change touches.
3. Report each problem as the screenshot, the element, what is wrong, and the fix. Fix, re-render,
   and look again. Three rounds that do not converge are a direction problem; stop and say so.

If nothing can be rendered (no dev server, no browser tool), say that plainly in the report. A
design judged only from source is unverified, and the report must not claim otherwise.

## Companion skills

Load on demand by task, never all at once. `frontend-design` is the only preload.

- `impeccable`: critique, polish, audit, and harden commands on an existing interface.
- `ui-ux-pro-max`: palette, font pairing, and chart-type lookup by product type.
- taste-skill presets, named by the read: `minimalist-ui`, `high-end-visual-design`,
  `industrial-brutalist-ui`; `redesign-existing-projects` for a redesign audit.
- `mockup-to-code` (Polaris): a screenshot or mockup the user supplies, built to match.
- `extract-design-system` (Polaris): a live site's tokens into `DESIGN.md`.
