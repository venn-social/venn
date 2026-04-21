/**
 * routes.ts — typed route constants so we never typo a path in `router.push()`.
 *
 * Usage:
 *   router.push(ROUTES.auth.login);
 */
export const ROUTES = {
  tabs: {
    home: '/',
    explore: '/explore',
    profile: '/profile',
  },
  auth: {
    login: '/auth/login',
    signup: '/auth/signup',
  },
} as const;
