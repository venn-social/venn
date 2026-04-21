/**
 * auth.service.ts — all auth API calls live here.
 *
 * Why a service layer?
 *   Screens and hooks should never call `supabase.auth.*` directly. Instead
 *   they call named service functions. That gives us:
 *     - One place to add logging, retries, or analytics on every auth call.
 *     - Easy mocking in tests (mock one module, not the whole Supabase SDK).
 *     - A typed, stable API that doesn't leak SDK internals into UI code.
 */
import { supabase } from '@/lib/supabase';

export interface SignUpParams {
  readonly email: string;
  readonly password: string;
  readonly username: string;
}

export interface SignInParams {
  readonly email: string;
  readonly password: string;
}

export async function signUp(params: SignUpParams): Promise<void> {
  const { error } = await supabase.auth.signUp({
    email: params.email,
    password: params.password,
    options: {
      data: { username: params.username },
    },
  });
  if (error) {
    throw new Error(error.message);
  }
}

export async function signIn(params: SignInParams): Promise<void> {
  const { error } = await supabase.auth.signInWithPassword({
    email: params.email,
    password: params.password,
  });
  if (error) {
    throw new Error(error.message);
  }
}

export async function signOut(): Promise<void> {
  const { error } = await supabase.auth.signOut();
  if (error) {
    throw new Error(error.message);
  }
}
