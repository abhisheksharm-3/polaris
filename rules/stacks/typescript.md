# TypeScript Stack Rules

<!-- Polaris opinions the generic TypeScript skill does not carry. -->

## Before starting

Detect the version and fetch fresh docs per the core docs protocol:
```bash
cat package.json | grep -E '"(typescript|zod)"'
```

## Types live only in dedicated type files

Every `type`, `interface`, `z.infer<>`, enum-like union, prop type, API shape, and store shape
belongs in a `types.ts` file (or a `types/` directory), never in a component, hook, or action
file.

```typescript
// WRONG: type in a component file
type UserCardPropsType = { user: UserType; onDelete: (id: string) => void };

// RIGHT: in features/users/types.ts, imported where needed
export type UserCardPropsType = { user: UserType; onDelete: (id: string) => void };
```

The only exception is a type so trivial and used once that extracting it adds confusion (for
example `type IdType = string`). When in doubt, extract.

## No barrel exports

No `index.ts` that re-exports from other modules. Barrels hide the true import source, create
circular-dependency traps, break tree-shaking, and make moves risky.

```typescript
// BANNED
import { UserCard, UserType, createUserAction } from '@/features/users';
// REQUIRED: direct imports
import { UserCard } from '@/features/users/components/UserCard';
import type { UserType } from '@/features/users/types';
import { createUserAction } from '@/features/users/actions';
```

If a feature has many externally-used exports, it is doing too much. Split it, do not barrel it.

## Extract complex inline types

Never write a complex type inline. Extract to a named top-level type. A type is complex if it has
more than one property, uses union or intersection, or is used more than once.

```typescript
// WRONG
const actions: Array<{ type: 'shell' | 'restart'; shell?: string }> = [];
// RIGHT
type DeployActionType = { type: 'shell'; shell: string } | { type: 'restart' };
const actions: DeployActionType[] = [];
```

## No inline async imports

Dynamic `import()` inside a function body is only for genuine lazy-loading. A static top-level
import should be the default; an unnecessary dynamic import forces callers to become async.

## No type escape hatches

No `as any`, no `value as unknown as T`, no `@ts-ignore` or `@ts-expect-error` without a comment
linking a verified framework bug. Fix the underlying type instead. All exported functions have
explicit return types.

## Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Components / component files | PascalCase | `UserProfileCard.tsx` |
| Hooks | camelCase with `use` | `useUserProfile` |
| Utility / action files | kebab-case | `format-date.ts`, `create-user.ts` |
| Boolean state | `is` / `has` / `should` | `isLoading`, `hasError` |
| Event handlers | `handle` prefix | `handleClick` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Types / interfaces | PascalCase with `Type` | `UserType` (no `I` prefix) |
| Zod schemas | PascalCase with `Schema` | `UserSchema` |
| Enums | PascalCase with `Enum` | `StatusEnum` |
| Server actions | camelCase with `Action` | `createUserAction` |
