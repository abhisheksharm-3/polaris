# Next.js Stack Rules

<!-- Stack: Next.js 15+, React 19, TypeScript strict, PostgreSQL, React Query, Zustand, Tailwind CSS, shadcn/ui, React Hook Form, Playwright (E2E) -->

## Agent Routing

You have four specialized agents for this Next.js project. Use them as follows:

| Situation | Agent to use |
|---|---|
| Starting a new feature, component, or API endpoint | `polaris:feature-builder` |
| Post-generation quality pass before a PR | `polaris:code-cleanup` |
| Systemic issues or full codebase restructuring | `polaris:audit-refactor` |
| Removing AI-generated artifacts from code | `polaris:slop-remover` |

## Global Rules (Zero Compromise)

- No `as any` casts. Ever.
- No workarounds. Solve the root problem.
- Full solutions only — no partial implementations left in place.
- Early development, zero users: zero backwards compatibility concerns.

## Naming Conventions
- Components: PascalCase (`UserCard`, `DashboardLayout`)
- Files: kebab-case (`user-card.tsx`, `dashboard-layout.tsx`)
- Types: PascalCase with `Type` suffix (`UserType`, `OrderType`)
- Schemas: PascalCase with `Schema` suffix (`UserSchema`)
- Enums: PascalCase with `Enum` suffix (`StatusEnum`)
- Server actions: camelCase with `Action` suffix (`createUserAction`)
- React Query hooks: camelCase with `use` prefix + `Query`/`Mutation` suffix

## Directory Structure
- Feature-based organization: `src/features/<feature>/components/`, `actions/`, `hooks/`, `types/`
- No cross-feature imports. Features communicate through shared `src/lib/` only.
- Shared UI components: `src/components/ui/` (shadcn/ui base)
- Custom shared components: `src/components/shared/`

## Data Flow (strict order)
1. Types (`types.ts`) — define data shapes first
2. Schemas (`schemas.ts`) — Zod schemas derived from types, not duplicated
3. Database (`db/`) — Drizzle queries/mutations
4. Server Actions (`actions.ts`) — validate with Zod, call DB layer
5. React Query hooks (`hooks/`) — wrap server actions for client state
6. UI Components — consume hooks, never call DB or actions directly

## TypeScript
- All types derived from Zod schemas. Never define the same type twice.
- No `@ts-ignore`. Fix the type error properly.
- Strict mode enabled — treat all `any` as compile errors.

## React Query
- Mandatory for all client-side data fetching. No raw `fetch()` in components.
- Queries invalidated on mutations, not page refreshes.

## Next.js
- Server Components by default. Add `'use client'` only when state/effects are required.
- Protect all server actions with session validation before accessing DB.
- Use `next/image` for all images. Never raw `<img>`.

## Accessibility
- All interactive elements keyboard-navigable.
- Meaningful `aria-label` on icon-only buttons.
- Color contrast ≥ 4.5:1 for text.
