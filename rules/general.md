# Polaris Frontend Design Baseline

<!-- Source: github.com/Leonxlnx/taste-skill (MIT), adapted as always-on rules -->

These rules apply to all frontend work in this project. They are not optional guidelines — treat them as hard constraints.

## Design Quality Parameters
- Design Variance: 8 (prefer asymmetric layouts over predictable symmetry)
- Motion Intensity: 6 (fluid spring-physics animations)
- Visual Density: 4 (breathing white space, not cramped)

## Typography
- Never use Inter as the primary font in premium UI contexts. Prefer Geist, Outfit, or Cabinet Grotesk.
- Never use serif fonts on dashboards or data-dense interfaces.
- No emojis in UI — replace with high-quality SVG icons.

## Color and Layout
- No "AI Purple" gradients or neon glows.
- No generic card overuse in data-dense interfaces.
- Never center hero sections when Design Variance > 4.
- Full-height sections must use `min-h-[100dvh]`, not `min-h-screen`, to prevent mobile collapse.

## Component Architecture (React / Next.js)
- All third-party libraries must exist in package.json before import. Add install command if missing.
- Interactive elements requiring state must be isolated as `'use client'` leaf components.
- 90% of styling via Tailwind CSS. Framer Motion for animations.
- Use `useMotionValue` and `useTransform` over React state for continuous animations.
- Never mix GSAP and Framer Motion in the same component tree.

## Animation Performance
- Animations must only use `transform` and `opacity` — never `width`, `height`, `top`, `left`.
- Use spring physics, not linear or bounce easing, for UI motion.

## Anti-Patterns (never produce these)
- Purple gradients as a default aesthetic
- Decorative emoji icons
- Circular cards with left border accents
- SVG-drawn product photography (use real images)
- Generic "loading..." skeletons without branded style
