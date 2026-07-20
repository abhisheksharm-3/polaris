---
description: >
  Use to reverse-engineer a design system from a live or public website — pull its
  color, typography, spacing, radius, and shadow into a DESIGN.md token set. Trigger
  when the user wants to match an existing brand or site, seed a new project's tokens
  from a reference URL, or answer "what tokens does this site use". For generating a
  design system from product reasoning (no reference site) use ui-new; for extracting
  tokens from THIS project's own code use impeccable's `extract` command instead.
---

<!-- Source: github.com/arvindrk/extract-design-system (MIT). The extraction engine is an
     external npm CLI invoked on demand; Polaris does not bundle it. -->

# Extract design system

Turn a live URL into a starter token set. The engine is the `extract-design-system` npm CLI (it
drives a headless browser via Playwright); this skill runs it on demand and maps its output into
Polaris's DESIGN.md format so `ui-new` and the `ui` agent can build against it.

## Prerequisite

The engine needs Node and `npx` on the machine. Check first:

```
command -v npx >/dev/null || echo "npx not found"
```

If `npx` is missing, tell the user the tool needs Node and stop. Do not hand-invent tokens from a
screenshot — a fabricated palette is worse than none.

## Steps

1. Confirm the target is a URL the user is entitled to reference, and that `npx` is available.
2. Run the engine against the URL, writing to a temp dir:
   ```
   npx --yes extract-design-system <url> --out <tmp>/tokens
   ```
   It produces `tokens.json` (and usually `tokens.css`). If the run fails (site blocks headless
   browsers, network error), report the failure and stop — do not guess tokens.
3. Read `tokens.json` and map it into a `DESIGN.md` token set, one section each: **color** (with
   roles, not just raw hex), **typography** (families, scale, weights), **spacing** (the scale),
   **radius**, and **shadow**. Name tokens by role (`--color-surface`, `--space-4`), not by value.
4. Flag what the tool cannot infer (semantic color roles, dark-mode pairs, motion) as `TODO` in
   DESIGN.md rather than leaving a raw dump. Extraction seeds a system; a human still decides intent.
5. Hand the DESIGN.md to `ui-new` or the `ui` agent to build against.

## Boundary

This reads a live site's *rendered* result, so it captures what a page ships, not the source's
intent. Treat the output as a first draft to refine, never as the final system. For a project's own
code, impeccable's `extract` is the better path; for a from-scratch system, use `ui-new`.
