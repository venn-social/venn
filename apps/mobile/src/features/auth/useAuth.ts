import { useContext } from 'react';

import { AuthContext } from '@/features/auth/AuthProvider';

import type { AuthContextValue } from '@/features/auth/auth.types';

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (ctx === null) {
    throw new Error('useAuth must be called inside <AuthProvider>.');
  }
  return ctx;
}
