# Coding Standards

Most of these are enforced by ESLint, Prettier, and the TypeScript compiler. The rest are enforced by reviewers. This doc exists so you know what to expect before you get a "please change this" comment on a PR.

## Anti-patterns we reject

### 1. `any` in TypeScript

```ts
// Bad
function save(data: any) { ... }

// Good
interface Draft { id: string; body: string; }
function save(data: Draft) { ... }
```

`any` turns off type checking for everything it touches. If you genuinely don't know the shape, use `unknown` and narrow it with a type guard.

### 2. Hardcoded colors, spacing, or font sizes

```tsx
// Bad
<Text style={{ color: '#333333', fontSize: 14, marginTop: 12 }} />

// Good
<Text variant="caption" color="textMuted" style={{ marginTop: spacing.md }} />
```

Use tokens from `src/constants/theme.ts`. When the theme changes, you want to change one file, not a hundred.

### 3. Magic numbers and strings

```ts
// Bad
if (username.length < 3 || username.length > 24) { ... }

// Good
import { LIMITS } from '@venn/shared';
if (username.length < LIMITS.USERNAME_MIN || username.length > LIMITS.USERNAME_MAX) { ... }
```

Constants have names that explain what they are. Numbers in code don't.

### 4. Giant components

If a component is more than ~100 lines, break it up. If it's more than ~200 lines, it almost certainly needs to be broken up. Pull pieces into sub-components or extract logic into a hook.

### 5. Business logic inside screens

```tsx
// Bad — the screen is directly talking to Supabase.
export default function FeedScreen() {
  const [posts, setPosts] = useState([]);
  useEffect(() => {
    supabase.from('posts').select('*').then(...)
  }, []);
  ...
}

// Good — the screen delegates to a feature hook.
export default function FeedScreen() {
  const feed = useFeed();
  ...
}
```

Screens render. Hooks compose. Services talk to the backend. See [`ARCHITECTURE.md`](./ARCHITECTURE.md).

### 6. Commented-out code

Delete it. Git remembers. Commented-out code rots: in three months, nobody knows whether it's supposed to come back or not.

### 7. `useEffect` for things that aren't effects

```tsx
// Bad — deriving state in useEffect.
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(`${first} ${last}`);
}, [first, last]);

// Good — derive it.
const fullName = `${first} ${last}`;
```

[React's own docs](https://react.dev/learn/you-might-not-need-an-effect) have a great article on this. Read it once.

### 8. Inline styles that could be `StyleSheet` objects

```tsx
// Worse — re-created on every render, no lint checks.
<View style={{ flex: 1, padding: 16 }} />;

// Better
const styles = StyleSheet.create({ root: { flex: 1, padding: spacing.md } });
<View style={styles.root} />;
```

`StyleSheet.create` allows React Native to optimize and lets ESLint catch unused styles.

### 9. `!` non-null assertion

```ts
// Bad
const post = posts.find((p) => p.id === id)!;

// Good
const post = posts.find((p) => p.id === id);
if (post === undefined) {
  throw new Error(`Post ${id} not found`);
}
```

`!` lies to the compiler. When the assumption fails in production, the crash is cryptic. Check and throw a clear error instead.

### 10. Mutating props or state directly

```ts
// Bad
function likePost(post: Post) {
  post.likeCount += 1;
}

// Good
function likePost(post: Post): Post {
  return { ...post, likeCount: post.likeCount + 1 };
}
```

React compares references. Mutating in place makes your UI not update.

## Patterns we like

### Small, single-purpose functions

```ts
// Instead of one 80-line function, three 15-line ones that compose.
export async function publishPost(draft: Draft): Promise<Post> {
  const validated = validateDraft(draft);
  const uploaded = await uploadMedia(validated);
  return createPostRow(uploaded);
}
```

### Discriminated unions for state

```ts
type Loadable<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: string };
```

Three booleans (`loading`, `error`, `hasData`) let you represent impossible states like "loading AND error." A discriminated union doesn't.

### `readonly` props

```ts
interface ButtonProps {
  readonly label: string;
  readonly onPress: () => void;
}
```

If a prop is mutated, TypeScript complains. Catches accidental bugs.

### Explicit return types on exported functions

```ts
// Good
export function formatCount(n: number): string { ... }

// Also fine internally, but be explicit at module boundaries.
```

This stops a refactor from silently changing the shape of a function's output.

### Error messages that tell you what to do

```ts
// Bad
throw new Error('invalid');

// Good
throw new Error(
  `Missing required env var: EXPO_PUBLIC_SUPABASE_URL. ` +
    `Copy apps/mobile/.env.example to apps/mobile/.env and fill in the values.`,
);
```

A good error message tells you where the problem is _and_ how to fix it.

## File structure inside a module

```ts
// 1. All imports at the top (ESLint enforces ordering).
import { useMemo } from 'react';
import { View } from 'react-native';

import { Button } from '@/components/ui';

// 2. Types.
interface Props { ... }

// 3. Constants.
const MAX_LINES = 3;

// 4. Helper functions that aren't exported.
function toDisplayName(first: string, last: string): string { ... }

// 5. The main exported thing(s).
export function ProfileCard(props: Props) { ... }

// 6. Styles at the bottom.
const styles = StyleSheet.create({ ... });
```

This order is not enforced by a tool, but reviewers watch for it.

## Security

Three rules with teeth. Each maps to a non-negotiable rule in [`CLAUDE.md`](../CLAUDE.md). The first two are partly enforced by tooling; the third is enforced by review.

### 1. Secrets — never in source

Every secret value is read from `.env` through the typed helper. Don't hardcode keys, even briefly, even in a file you "won't commit." Git remembers.

```ts
// Bad — hardcoded.
const supabaseUrl = 'https://abcd1234.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsIn...';

// Bad — reading process.env directly skips the validation in lib/env.ts.
const url = process.env.EXPO_PUBLIC_SUPABASE_URL;

// Good — typed, validated, fails loudly if the value is missing or malformed.
import { env } from '@/lib/env';
const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY);
```

The mobile app only sees `EXPO_PUBLIC_*` variables — those are bundled into the iOS/Android binary and shipped to every user's device. Anything else (service-role keys, third-party server tokens) is server-only.

A `Secret scan` GitHub Action runs gitleaks on every PR. If you commit a key by accident, CI blocks the merge. Locally, `git secrets` or just `npm run doctor` is your friend.

### 2. Sanitize every user input

Anything a user can type goes through a Zod schema in [`src/utils/sanitize.ts`](../apps/mobile/src/utils/sanitize.ts) before it hits a service, the database, or another user's screen. Don't sprinkle ad-hoc `if (input.length > 24)` around screens — extend the shared schemas instead.

```ts
// Bad — validation embedded in the screen, no normalization.
const handleSignUp = async () => {
  if (username.length < 3) {
    setError('username too short');
    return;
  }
  await createAccount(username);
};

// Good — schema-validated, normalized, lowercased before it ever leaves the screen.
import { UsernameSchema } from '@/utils/sanitize';

const handleSignUp = async () => {
  const result = UsernameSchema.safeParse(username);
  if (!result.success) {
    setError(result.error.issues[0]?.message ?? 'invalid username');
    return;
  }
  await createAccount(result.data); // already normalized + lowercased
};
```

What `normalizeText` strips: zero-width unicode (U+200B-200F, used for spoofing), bidi-override chars (used to disguise filenames or display names), C0/C1 control chars, leading/trailing whitespace, and runs of internal whitespace. It's NFC-normalized and idempotent.

Server-side enforcement (Postgres `CHECK` constraints, length caps, RLS policies) is the final line of defense. Each migration that introduces a user-typed column must include the matching constraint.

### 3. Rate limiting

Every Supabase Edge Function and every RPC we add must include a server-side rate limit. The pattern: a `rate_limits` table keyed by `(user_id, action)` with a sliding window enforced by a Postgres function the edge function calls before doing the real work.

We don't have any edge functions or RPCs yet, so the SQL pattern lives here as a reference for when we add the first one:

```sql
-- One time, in a migration:
create table public.rate_limits (
  user_id uuid not null,
  action text not null,
  ts timestamptz not null default now(),
  primary key (user_id, action, ts)
);
create index rate_limits_lookup_idx on public.rate_limits (user_id, action, ts desc);

create or replace function public.check_rate_limit(
  p_action text,
  p_max_calls int,
  p_window_seconds int
) returns void
language plpgsql
security definer
as $$
declare
  call_count int;
begin
  delete from public.rate_limits
   where user_id = auth.uid()
     and action = p_action
     and ts < now() - (p_window_seconds || ' seconds')::interval;

  select count(*) into call_count
    from public.rate_limits
   where user_id = auth.uid()
     and action = p_action;

  if call_count >= p_max_calls then
    raise exception 'rate_limit_exceeded' using errcode = '429';
  end if;

  insert into public.rate_limits (user_id, action) values (auth.uid(), p_action);
end;
$$;
```

Every new RPC or Edge Function then starts with `select check_rate_limit('post_create', 10, 60);` (or whatever the limits should be) before it does anything else.

The client-side limiter in [`src/utils/rateLimit.ts`](../apps/mobile/src/utils/rateLimit.ts) is for UX only — it stops a user from accidentally double-tapping a "post" button or hammering the search box. It does NOT replace server-side enforcement; anything in JavaScript on a user's device can be bypassed.

## PR review rubric

When you review, look for:

1. Does the code do what the PR description says?
2. Are there tests for new logic?
3. Are names clear? (Worth re-reading: the [Linux kernel naming doc](https://www.kernel.org/doc/html/v5.12/process/coding-style.html#naming).)
4. Would a teammate who didn't write this understand it in six months?
5. Are there any of the anti-patterns listed above?

Be kind. Every comment is on the code, never on the person.
