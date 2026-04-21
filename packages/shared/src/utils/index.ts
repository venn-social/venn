/**
 * Pure cross-platform utilities. Must not depend on React, React Native,
 * or any platform-specific API. If a function needs AsyncStorage, window,
 * or similar, it belongs in the app's own utils instead.
 */

import { LIMITS } from '@venn/shared/constants';

export function isValidUsername(value: string): boolean {
  if (value.length < LIMITS.USERNAME_MIN || value.length > LIMITS.USERNAME_MAX) {
    return false;
  }
  return /^[a-z0-9_.]+$/i.test(value);
}
