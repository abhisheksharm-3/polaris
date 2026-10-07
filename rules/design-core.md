# Polaris core design standard

<!-- Injected every session by hooks/inject-cores, beside core.md, so design has the standing -->
<!-- development has. Its own hook, because core.md's payload already sits near the 10,000- -->
<!-- character cap. Budget: 3,000 bytes. The full standard is rules/design.md. -->

Design is first-class here, held to the same bar as code. A change a user will see is not done when
it compiles. It is done when it follows the design contract and someone has looked at it rendered.

1. **DESIGN.md is the contract.** The repo-root `DESIGN.md` holds the tokens, components, dials,
   and do's and don'ts. Read it before writing or judging UI. A value the UI needs that is not there
   gets added there, never hardcoded as a one-off. No DESIGN.md yet means direction comes first.
2. **Read, then dial.** Before markup, write one line: "Reading this as: <page kind> for
   <audience>, in a <vibe> language." Then set VARIANCE, MOTION, and DENSITY (1-10). The audience
   picks the aesthetic, not habit.
3. **No default nobody chose.** Unexamined Inter, an AI-purple gradient, a centered hero over a
   dark mesh, three equal feature cards, an eyebrow on every section, emoji as icons, a product UI
   faked from divs, an unstyled component-library default. Each is the signature of no decision.
4. **Every state is designed.** Loading as a skeleton, empty that teaches, error that says how to
   recover, disabled that is inert. Keyboard path, visible focus, AA contrast in both themes.
5. **Motion earns its place.** `transform` and `opacity` only, never `transition: all`, ease-out in,
   ease-in out, interruptible, `prefers-reduced-motion` honored. `100dvh`, never `100vh`.
6. **See it.** Render it at 375, 768, and 1440 px, in light and dark, and look before calling it
   done. If it cannot be rendered, say so; never claim a design is right from source alone.

Design work routes to the `design` flow (`/polaris:design`). The feature flow runs the ux agent's
`experience` phase before architecture. Load on demand: `rules/design.md` for any UI, UX, or
visual work; `rules/design-interface.md` for the interface checklist.
