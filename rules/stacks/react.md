# React Stack Rules (non-Next.js)

## Component Architecture
- Functional components only. No class components.
- Custom hooks for all reusable stateful logic.
- `'use client'` not applicable here — manage data fetching with React Query or SWR.

## Data Fetching
- React Query (TanStack Query) for all server state.
- No raw `fetch()` inside components — always in a query function.

## Styling
- Tailwind CSS preferred. CSS Modules acceptable for complex scoped styles.
- No inline `style={{}}` except for dynamic values that can't be expressed in Tailwind.

## Performance
- `React.memo()` only when profiling shows a real problem.
- `useCallback` for event handlers passed as props to memoized children.
- Lazy load routes with `React.lazy()` + `Suspense`.

## Quality Gates
- No `as any`.
- All props typed with explicit interfaces (no implicit `any` from missing types).
- Components under 200 lines — split if larger.
