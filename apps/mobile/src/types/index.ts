/**
 * Shared domain types used across the app. Keep them small and pure.
 * If a type is specific to one feature, define it inside that feature folder
 * (e.g. src/features/auth/auth.types.ts) instead of here.
 */

export interface UserProfile {
  readonly id: string;
  readonly username: string;
  readonly displayName: string;
  readonly avatarUrl: string | null;
  readonly bio: string | null;
  readonly createdAt: string;
}

export interface Post {
  readonly id: string;
  readonly authorId: string;
  readonly caption: string;
  readonly mediaUrl: string | null;
  readonly likeCount: number;
  readonly commentCount: number;
  readonly createdAt: string;
}

/**
 * A generic "loadable" state. Use this to model anything async.
 * Much easier to reason about than keeping `loading`, `error`, and `data` as
 * three independent useState hooks.
 */
export type Loadable<T> =
  | { readonly status: 'idle' }
  | { readonly status: 'loading' }
  | { readonly status: 'success'; readonly data: T }
  | { readonly status: 'error'; readonly error: string };
