/**
 * AuthProvider — listens to Supabase auth state and exposes it via context.
 *
 * Wrap the root of the app in <AuthProvider>. Anywhere deeper in the tree,
 * call `useAuth()` to read `{ user, session, isLoading }`.
 */
import { createContext, useEffect, useMemo, useState } from 'react';

import type { AuthContextValue } from '@/features/auth/auth.types';
import type { Session, User } from '@supabase/supabase-js';
import type { PropsWithChildren } from 'react';

import { supabase } from '@/lib/supabase';

export const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!isMounted) {
        return;
      }
      setSession(data.session);
      setUser(data.session?.user ?? null);
      setIsLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      setUser(newSession?.user ?? null);
    });

    return () => {
      isMounted = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ user, session, isLoading }),
    [user, session, isLoading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
