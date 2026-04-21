import { useContext } from 'react';

import type { AuthContextValue } from '@/features/auth/auth.types';

import { AuthContext } from '@/features/auth/AuthProvider';

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (ctx === null) {
    throw new Error('useAuth must be called inside <AuthProvider>.');
  }
  return ctx;
}
