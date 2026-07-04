# React Stack Rules (non-Next.js)

---

## Before Starting Any Work

Check installed versions:
```bash
cat package.json | grep -E '"(react|react-dom|@tanstack/react-query|zustand|vite|typescript)"'
```

Fetch current docs:
- **React 19**: WebFetch `https://react.dev/reference/react` — useOptimistic, useTransition, use()
- **React Query v5**: WebFetch `https://tanstack.com/query/latest/docs/framework/react/overview`
- **Vite**: WebFetch `https://vitejs.dev/guide/` if used as build tool
- **Zustand**: WebFetch `https://docs.pmnd.rs/zustand/getting-started/introduction`

---

## React 19 — Required Features

### useOptimistic for all mutations
```typescript
const [optimisticItems, addOptimistic] = useOptimistic(
  items,
  (state, newItem: ItemType) => [...state, { ...newItem, pending: true }]
);
```

### useTransition for non-urgent updates
```typescript
const [isPending, startTransition] = useTransition();

function handleFilterChange(filter: FilterType) {
  startTransition(() => setActiveFilter(filter));
}
```

### use() for Suspense-based async
```typescript
// In a component wrapped in <Suspense>
const data = use(fetchDataPromise);
```

### ref as prop (no forwardRef)
```typescript
function Input({ ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
```

---

## Component Architecture

- **Functional components only** — no class components
- **Server Components**: not available in pure React (non-Next.js) — all components are client-side
- **Custom hooks** for all reusable stateful logic (one hook per file)
- **Co-locate** component, its hook, and its types in the same feature directory
- **No prop drilling beyond 2 levels** — use Zustand store or React Context

## Data Fetching

- **React Query for all server state** — no raw `fetch()` inside components
- **Zustand for client-only state** (UI state, preferences, offline data)
- **Never mix** server state in Zustand (it has no invalidation/sync mechanism)

```typescript
// Query — in hooks/use-users-query.ts
export function useUsersQuery() {
  return useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const response = await fetch('/api/users');
      if (!response.ok) throw new Error('Failed to fetch users');
      return response.json() as Promise<UserType[]>;
    },
    staleTime: 60_000,
  });
}

// Mutation with optimistic update
export function useCreateUserMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateUserInputType) =>
      fetch('/api/users', { method: 'POST', body: JSON.stringify(data) }).then(r => r.json()),
    onMutate: async (newUser) => {
      await queryClient.cancelQueries({ queryKey: ['users'] });
      const previous = queryClient.getQueryData<UserType[]>(['users']);
      queryClient.setQueryData<UserType[]>(['users'], old => [...(old ?? []), { id: 'temp', ...newUser }]);
      return { previous };
    },
    onError: (_err, _vars, context) => {
      queryClient.setQueryData(['users'], context?.previous);
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  });
}
```

## Styling

- **Tailwind CSS** for 90% of styling
- **CSS Modules** only for complex scoped animations or third-party component overrides
- **No inline `style={{}}`** except for truly dynamic values (e.g., calculated widths from JS)
- **No hardcoded hex values** — use Tailwind config tokens

## Performance

- `React.memo()` only after profiling confirms a re-render problem — not preemptively
- `useCallback` for event handlers passed to memoized child components
- `useMemo` for expensive computations, not for derived state that is cheap to compute
- Lazy load route-level components: `const Page = React.lazy(() => import('./Page'))`
- Always wrap lazy routes in `<Suspense fallback={<PageSkeleton />}>`

## TypeScript

- No `as any`, `@ts-ignore`, `@ts-expect-error`
- All props typed with explicit interfaces (no `{}` or `object`)
- All exported functions have explicit return types
- All types extracted to `types.ts` — no inline complex types

## Quality Gates

- Components under 150 lines — split if larger
- No duplicate utility functions — search before creating
- No orphan files — every file is imported somewhere
- JSDoc on all exported hooks and utility functions

## Frontend design baseline

Typography:
- Never use Inter as the primary font in premium UI. Prefer Geist, Outfit, or Cabinet Grotesk.
- Never use serif fonts on dashboards or data-dense interfaces.
- No emojis in UI. Use high-quality SVG icons.

Color and layout:
- No "AI purple" gradients or neon glows as a default aesthetic.
- No generic card overuse in data-dense interfaces.
- Full-height sections use `min-h-[100dvh]`, not `min-h-screen` (mobile collapse).

Animation performance:
- Animate only `transform` and `opacity`, never `width`, `height`, `top`, `left`.
- Spring physics over linear or bounce easing.
- `useMotionValue` and `useTransform` over React state for continuous animations.
- Never mix GSAP and Framer Motion in the same component tree.

Anti-patterns to never produce:
- Purple gradients as a default aesthetic
- Decorative emoji icons
- Circular cards with left border accents
- SVG-drawn product photography (use real images)
- Centered hero sections when the content is asymmetric
- Generic "loading..." skeletons without a branded style
