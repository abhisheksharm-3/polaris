# Polaris Universal Code Quality Rules

<!-- Source: Taste-Skill (MIT) + Polaris project standards -->
<!-- Injected into every session. These are hard constraints, not suggestions. -->

---

## Philosophy

Every line of code must be sustainable for 1000+ concurrent users in production. There are no users yet, so there are zero backwards-compatibility concerns — do things RIGHT. Organized, zero tech debt. Never create compatibility shims.

---

## Fetch Latest Docs Before Starting

Before implementing anything in a project, determine the installed version of the primary framework:

```bash
# For Node projects
cat package.json | grep -E '"(next|react|vue|svelte|astro)"'

# For Python projects
cat pyproject.toml | grep -E '(fastapi|django|flask)'

# For Rust projects
cat Cargo.toml | grep -E '(version|axum|tokio)'
```

Then use **WebFetch** or **WebSearch** to retrieve official docs for that exact version before writing any implementation. Never rely on training data for version-specific APIs — always verify.

Example:
- Detect `"next": "^15.2.0"` → fetch `https://nextjs.org/docs` for current App Router APIs
- Detect `fastapi==0.115.0` → search `"FastAPI 0.115 async dependency injection best practices"`

---

## Implementation Standards

### No Workarounds. Ever.
- If you cannot implement something correctly, stop and explain why — do not write a workaround
- No `// TODO: fix this later` — fix it now or don't write it
- No half-baked solutions — every feature must be production-ready when merged
- No `as any`, `@ts-ignore`, `@ts-expect-error` without a documented framework bug reason
- No bare `catch` blocks that swallow errors silently

### One File, One Responsibility
Every file must have a single, clearly stated purpose. If you cannot describe what a file does in one sentence without using "and", split it.

Signals a file needs splitting:
- Over 200 lines in a component file
- Over 150 lines in a utility/action file
- Multiple exported functions doing unrelated things
- Multiple classes or major concerns in one file

### No Orphan Code
- Every exported function, component, type, or constant must be imported somewhere
- Every file must be imported by at least one other file (or be an entry point)
- Every directory must contain at least one file that is actively used
- Delete dead code immediately — do not comment it out

### No Duplicate Code
Before writing a new utility function, search the codebase for existing implementations. If a function exists that does the same thing:
- Reuse it (add `export` if needed, move to a shared location if needed)
- Delete the duplicate
- Never have two functions that do the same thing in different files

### Extract Complex Inline Types
Never write complex types inline where they are used. Extract to a named top-level type.

```typescript
// WRONG — complex inline type
const actions: Array<{ type: 'shell' | 'restart'; shell?: string; restart?: { name: string } }> = [];

// RIGHT — extracted named type
type DeployActionType =
  | { type: 'shell'; shell: string }
  | { type: 'restart'; restart: { name: string } };

const actions: DeployActionType[] = [];
```

A type is "complex" if it has more than one property, uses union/intersection, or would be hard to read inline.

### No Inline Async Imports
Dynamic `import()` expressions inside function bodies should be rare — only when genuinely lazy-loading for performance.

```typescript
// WRONG — unnecessary dynamic import
async function doSomething() {
  const { parse } = await import('some-lib'); // forces caller to be async
  return parse(data);
}

// RIGHT — static top-level import
import { parse } from 'some-lib';

function doSomething() {
  return parse(data);
}
```

---

## Comments Policy

**Only JSDoc comments and single-line explanatory comments for non-obvious WHY.** No other comments.

### Allowed comments:
```typescript
/**
 * Validates a webhook signature using HMAC-SHA256.
 * Must be called before any database writes on this route.
 */
function validateWebhookSignature(payload: Buffer, signature: string): boolean { ... }

// Stripe requires idempotency keys to be unique per customer, not per request
const idempotencyKey = `${customerId}-${invoiceId}`;
```

### Forbidden comments (remove on sight):
```typescript
// This function handles user authentication   ← explains what, not why
// Added for backwards compatibility           ← backwards compat concern
// TODO: refactor this later                  ← deferred tech debt
// Removed X import - no longer needed        ← process journal
// Step 1: validate input                     ← narrates the code
const x = foo(); // call foo                  ← redundant inline comment
```

The rule: if removing the comment would not confuse a reader, remove it.

---

## Naming Conventions (Universal)

| Thing | Convention | Example |
|---|---|---|
| React components | PascalCase | `UserProfileCard`, `DashboardLayout` |
| Files containing components | PascalCase | `UserProfileCard.tsx` |
| Hooks | camelCase with `use` prefix | `useUserProfile`, `useAuthState` |
| Utility/action TS files | kebab-case | `format-date.ts`, `create-user.ts` |
| Boolean state variables | `is`, `has`, `should` prefix | `isLoading`, `hasError`, `shouldRedirect` |
| Event handler functions | `handle` prefix | `handleClick`, `handleInputChange`, `handleFormSubmit` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| TypeScript types | PascalCase with `Type` suffix | `UserType`, `OrderStatusType` |
| TypeScript interfaces | PascalCase with `Type` suffix | same as types — no `I` prefix |
| Zod schemas | PascalCase with `Schema` suffix | `UserSchema`, `CreateOrderSchema` |
| Enums | PascalCase with `Enum` suffix | `StatusEnum`, `RoleEnum` |
| Server actions | camelCase with `Action` suffix | `createUserAction`, `deletePostAction` |

---

## Frontend Design Baseline

### Typography
- Never use Inter as the primary font in premium UI. Prefer Geist, Outfit, or Cabinet Grotesk.
- Never use serif fonts on dashboards or data-dense interfaces.
- No emojis in UI — replace with high-quality SVG icons.

### Color and Layout
- No "AI Purple" gradients or neon glows.
- No generic card overuse in data-dense interfaces.
- Full-height sections use `min-h-[100dvh]`, not `min-h-screen` (mobile collapse prevention).

### Animation Performance
- Animations use only `transform` and `opacity` — never `width`, `height`, `top`, `left`.
- Spring physics over linear/bounce easing.
- `useMotionValue` and `useTransform` (Framer Motion) over React state for continuous animations.
- Never mix GSAP and Framer Motion in the same component tree.

### Anti-Patterns (never produce)
- Purple gradients as a default aesthetic
- Decorative emoji icons
- Circular cards with left border accents
- SVG-drawn product photography (use real images)
- Centered hero sections when content is asymmetric
- Generic "loading..." skeletons without branded style
