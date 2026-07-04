# Next.js 15 + React 19 Stack Rules

<!-- Stack: Next.js 15+, React 19, TypeScript 5 strict, PostgreSQL, Drizzle ORM, React Query v5, Zustand, Tailwind CSS v4, shadcn/ui, React Hook Form v7, Zod v3, Playwright -->

---

## Before Starting Any Work

Check installed versions:
```bash
cat package.json | grep -E '"(next|react|react-dom|@tanstack/react-query|zustand|drizzle-orm|zod)"'
```

Then fetch current official docs:
- **Next.js**: WebFetch `https://nextjs.org/docs` — focus on App Router, Server Components, Server Actions
- **React 19**: WebFetch `https://react.dev/blog/2024/12/05/react-19` — useOptimistic, useTransition, use(), useActionState
- **React Query v5**: WebFetch `https://tanstack.com/query/latest/docs/framework/react/overview`
- **Drizzle**: WebFetch `https://orm.drizzle.team/docs/overview`
- **Zod**: WebFetch `https://zod.dev`

Never implement version-specific APIs from memory — always verify against current docs.

---

## Agent Routing

| Situation | Agent |
|---|---|
| New feature, component, or API endpoint | `polaris:feature-builder` |
| Post-generation quality pass before PR | `polaris:code-cleanup` |
| Security audit, perf audit, architecture review | `polaris:audit-refactor` |
| Removing AI artifacts from code | `polaris:code-cleanup` |

---

## React 19 — Required Features

### useOptimistic
Use for all mutations that update UI state. Never wait for server confirmation before reflecting the change:

```typescript
const [optimisticItems, addOptimistic] = useOptimistic(
  items,
  (state, newItem: ItemType) => [...state, { ...newItem, pending: true }]
);

async function handleAddItem(formData: FormData) {
  const newItem = { id: crypto.randomUUID(), name: formData.get('name') as string };
  addOptimistic(newItem);
  await createItemAction(newItem);
}
```

### useTransition
Wrap all non-urgent state updates that might cause layout shifts. Use for search, filters, tab switching:

```typescript
const [isPending, startTransition] = useTransition();

function handleTabChange(tab: TabType) {
  startTransition(() => {
    setActiveTab(tab);
  });
}
```

### useActionState (replaces useFormState)
Use for Server Action state management in forms:

```typescript
const [state, formAction, isPending] = useActionState(createUserAction, { error: null });
```

### use() for Suspense-based data
Use `use()` to read promises and context in render:

```typescript
// Unwrap a promise in a Server Component child
const data = use(fetchDataPromise);
```

### ref as prop (no forwardRef needed)
```typescript
// React 19 — ref is a regular prop
function Input({ ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
```

### Actions in forms
```typescript
<form action={createUserAction}>
  <input name="email" type="email" required />
  <SubmitButton />
</form>
```

---

## Next.js 15 — Required Patterns

### Fetch Caching (breaking change in v15)
`fetch()` is **no longer cached by default** in Next.js 15. Always be explicit:

```typescript
// Cached (revalidated every hour)
const data = await fetch(url, { next: { revalidate: 3600 } });

// Never cached (dynamic)
const data = await fetch(url, { cache: 'no-store' });

// Cache tag for on-demand revalidation
const data = await fetch(url, { next: { tags: ['users'] } });
```

### Server Components by Default
Every component is a Server Component unless it needs interactivity:

```typescript
// Server Component — no 'use client', can be async
async function UserList() {
  const users = await db.select().from(usersTable);
  return <ul>{users.map(u => <UserCard key={u.id} user={u} />)}</ul>;
}

// Client Component — only when state/effects/browser APIs needed
'use client';
function SearchInput({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState('');
  // ...
}
```

### Server Actions
```typescript
'use server';

export async function createUserAction(formData: FormData): Promise<ActionResultType> {
  const session = await auth();
  if (!session) return { error: 'Unauthorized' };

  const parsed = CreateUserSchema.safeParse({
    name: formData.get('name'),
    email: formData.get('email'),
  });
  if (!parsed.success) return { error: parsed.error.flatten().fieldErrors };

  const [user] = await db.insert(usersTable).values(parsed.data).returning();
  revalidateTag('users');
  return { data: user };
}
```

### Parallel Routes and Intercepting Routes
Use for modals, side panels, and split layouts — not a single giant page component.

### next/image for ALL images
```typescript
// ALWAYS
<Image src="/hero.webp" alt="Hero" width={1200} height={600} priority />

// NEVER
<img src="/hero.webp" alt="Hero" />
```

---

## Data Flow (strict order — never skip steps)

```
Types → Schemas → Database → Server Actions → React Query Hooks → UI Components
```

1. **`types.ts`** — Define all data shapes as TypeScript types
2. **`schemas.ts`** — Zod schemas; all types derived with `z.infer<>`, never duplicated
3. **`db/`** — Drizzle queries and mutations; no business logic here
4. **`actions.ts`** — Server Actions; validate session + Zod before any DB call
5. **`hooks/`** — React Query hooks wrapping server actions
6. **`components/`** — Consume hooks only; never call DB or actions directly

---

## React Query v5

All client-side data fetching goes through React Query. No exceptions.

```typescript
// Query
export function useUsersQuery() {
  return useQuery({
    queryKey: ['users'],
    queryFn: () => getUsersAction(),
    staleTime: 60_000,
  });
}

// Mutation with optimistic update
export function useCreateUserMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateUserInputType) => createUserAction(data),
    onMutate: async (newUser) => {
      await queryClient.cancelQueries({ queryKey: ['users'] });
      const previous = queryClient.getQueryData<UserType[]>(['users']);
      queryClient.setQueryData<UserType[]>(['users'], old => [...(old ?? []), { ...newUser, id: 'temp' }]);
      return { previous };
    },
    onError: (_err, _vars, context) => {
      queryClient.setQueryData(['users'], context?.previous);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

**Never** use raw `fetch()` inside React components.

---

## TypeScript — Zero Tolerance

```typescript
// BANNED — all of these are immediate PR blockers
as any
as unknown as SomeType  // double-cast escape hatch
@ts-ignore
@ts-expect-error        // unless paired with framework bug link in comment
// eslint-disable

// REQUIRED
// All types derived from Zod:
type UserType = z.infer<typeof UserSchema>;

// Explicit return types on all exported functions:
export async function getUserAction(id: string): Promise<UserType | null> { ... }

// Discriminated unions over optional fields:
type ResultType<T> = { success: true; data: T } | { success: false; error: string };
```

---

## Types Isolation — Strict Rule

Every `type`, `interface`, and Zod-derived type lives **only** in a dedicated `types.ts` (or `types/` directory). Never defined inside component files, hook files, action files, or anywhere else.

```typescript
// BANNED — type defined in a component file
// features/users/components/UserCard.tsx
type UserCardPropsType = { user: UserType; onDelete: (id: string) => void };
export function UserCard({ user, onDelete }: UserCardPropsType) { ... }

// REQUIRED — type in types.ts, imported everywhere
// features/users/types.ts
export type UserCardPropsType = { user: UserType; onDelete: (id: string) => void };

// features/users/components/UserCard.tsx
import type { UserCardPropsType } from '../types';
export function UserCard({ user, onDelete }: UserCardPropsType) { ... }
```

All types are suffixed with `Type`. Zod schemas suffixed with `Schema`. No exceptions.

---

## No Barrel Exports

No `index.ts` files that re-export from other modules. Import directly from the source file.

```typescript
// BANNED — barrel file
// features/users/index.ts
export * from './UserCard';
export * from './types';
export * from './actions';

// REQUIRED — direct imports
import { UserCard } from '@/features/users/components/UserCard';
import type { UserType } from '@/features/users/types';
import { createUserAction } from '@/features/users/actions';
```

Barrel files hide import sources, create circular dependency traps, and break tree-shaking. If a feature exports too many things, it's doing too much — split it, don't barrel it.

---

## Directory Structure

```
src/
├── app/                    # Next.js App Router pages and layouts
│   ├── (auth)/             # Route group — auth pages
│   ├── (dashboard)/        # Route group — protected pages
│   └── api/                # API routes (webhooks, OAuth callbacks only)
├── features/               # Feature-based modules
│   └── [feature]/
│       ├── components/     # UI components for this feature (PascalCase files)
│       ├── hooks/          # React Query hooks (camelCase files)
│       ├── actions.ts      # Server Actions
│       ├── schemas.ts      # Zod schemas
│       └── types.ts        # TypeScript types
├── components/
│   ├── ui/                 # shadcn/ui base components (never modified)
│   └── shared/             # Custom shared components used across features
├── lib/
│   ├── db/                 # Drizzle schema, client, migrations
│   ├── auth/               # Auth config (next-auth or better-auth)
│   └── [utility]/          # Shared utility files (kebab-case)
└── types/                  # Global types used across multiple features
```

**Rules:**
- No feature imports from another feature — only from `src/lib/` or `src/components/`
- `app/` contains only page/layout/loading/error files — no business logic
- `components/ui/` is untouched shadcn/ui — customizations go in `components/shared/`

---

## Naming (Next.js specific)

| Thing | Convention | Example |
|---|---|---|
| Page files | lowercase | `page.tsx`, `layout.tsx` |
| Route groups | lowercase in parens | `(dashboard)/`, `(auth)/` |
| Dynamic segments | lowercase in brackets | `[id]/`, `[slug]/` |
| Server actions | camelCase + `Action` | `createUserAction`, `deletePostAction` |
| React Query hooks | camelCase + `use` + noun + `Query`/`Mutation` | `useUsersQuery`, `useCreateUserMutation` |
| Zustand stores | camelCase + `Store` | `useUserStore`, `useCartStore` |
| Boolean state | `is`/`has`/`should` prefix | `isLoading`, `hasError`, `shouldRedirect` |
| Event handlers | `handle` prefix | `handleSubmit`, `handleSearchChange` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_FILE_SIZE`, `DEFAULT_PAGE_SIZE` |

---

## Performance Requirements

- **No N+1 queries** — use Drizzle `with()` for relations or batch with `inArray()`
- **Streaming** — use `Suspense` with `loading.tsx` for all async Server Components
- **Images** — always `next/image` with explicit `width`/`height`, `priority` on above-fold
- **Fonts** — use `next/font` with `display: 'swap'`, never load from Google directly
- **Bundle size** — prefer named imports; audit with `@next/bundle-analyzer` before shipping features
- **React Query** — set `staleTime` intentionally; never use default `0` for expensive queries
- **Server Components** — push data fetching to the server; minimize `'use client'` boundaries

---

## Security Requirements

- All Server Actions validate session with `auth()` before any DB operation
- All user input validated with Zod before hitting the database
- Never expose internal IDs — use nanoid or cuid for public-facing identifiers
- Environment variables: `NEXT_PUBLIC_` prefix only for values safe to expose to the browser
- Never `console.log` request bodies, user data, or tokens in production code
- Rate limiting on all Server Actions that mutate data
- CSRF protection is built into Next.js Server Actions — do not disable it

---

## Accessibility Requirements

- All interactive elements keyboard-navigable (Tab order, Enter/Space for buttons)
- All images have meaningful `alt` (empty `alt=""` for decorative images)
- Icon-only buttons have `aria-label`
- Color contrast ≥ 4.5:1 for normal text, ≥ 3:1 for large text
- Form inputs linked to labels via `htmlFor`/`id`
- Error messages programmatically associated with inputs via `aria-describedby`
