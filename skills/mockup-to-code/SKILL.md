---
name: mockup-to-code
description: Use to build UI that matches an image the user supplies — a screenshot, a mockup, a Figma export, a photo of a sketch, or a reference site capture. Analyzes the image as a spec, writes the tokens into DESIGN.md, builds it, then renders and compares side by side until it matches. Trigger phrases include "build this from the screenshot", "match this mockup", "recreate this design", "make it look like this image".
---

<!-- Adapted from the image-to-code skill in github.com/Leonxlnx/taste-skill (MIT). Upstream -->
<!-- generates the reference images first, which needs a native image tool Claude Code lacks. -->
<!-- This keeps its analysis, extraction, and anti-drift discipline for images the user supplies, -->
<!-- and adds the render-and-compare loop that proves the match. -->

# Mockup to code

The image is the spec. The failure this skill exists to stop is drift: the reference looks
distinct, and the coded result comes out generic because the builder filled every unclear detail
with a default.

## Inputs

- One or more image paths. Read each with the Read tool, which shows it to you.
- Whether the target is exact reproduction (the user's own design) or a reference to adapt (someone
  else's site). A third party's design is adapted, never cloned: its layout logic and rhythm carry
  over, its brand, copy, and imagery do not.

## Steps

1. **Read the room.** Write the design read and the dials (`rules/design.md`) the image implies.
2. **Analyze before coding.** For each image, section by section, write down:
   - the visible text, verbatim where readable (headline, sub, calls to action, nav, section titles)
   - the type: families or their closest available match, size ratios, weights, line counts,
     tracking, where display and body split
   - the spacing: gutters, section padding, gaps between heading, body, and action, card padding,
     and the rhythm across sections, as a scale rather than pixel guesses
   - the components: button shapes, fill and outline hierarchy, radii, borders, dividers, shadows,
     inputs, badges
   - the color: background, surfaces, text hierarchy, accent, borders, shadow tint
   - the grid, alignment, and section order
   - what is unclear. Ask for a closer crop or a second image before guessing; do not fill a gap
     with a default.
3. **Write the tokens down.** Put the extracted palette, type scale, spacing scale, radii, and
   component rules into `DESIGN.md` (create it in the Stitch format `rules/design.md` describes, or
   extend the existing one). Existing project tokens win where they conflict; say where they did.
4. **Build it** to the tokens, mobile collapse declared per section, every interactive state the
   image implies plus the ones it cannot show (focus, loading, empty, error).
5. **Render and compare.** Screenshot the result at the image's own width and put it beside the
   reference. List each difference: position, size, spacing, weight, color, wrap. Fix and re-render.
   Stop when the remaining differences are ones the platform or the available fonts force, and name
   those. Then check 375 and 1440 as `rules/design.md` requires.

## Anti-drift

While building, do not:

- replace a distinctive section with a generic row, or merge sections into a repeated pattern the
  image does not have
- compress generous spacing into a dense layout, or flatten a strong type scale into default
  headings
- swap the palette for framework default colors
- add nested cards, badges, or micro-labels the image does not show
- "improve" the design. A change to the reference is a question for the user, not a fix.

## Output

The built UI, the `DESIGN.md` changes, the side-by-side comparison screenshots, and a short list of
the differences left and why. If the result could not be rendered, say so; a match claimed from
source is unverified.
