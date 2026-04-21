/**
 * supabase.ts — single, shared Supabase client for the app.
 *
 * Always import the client from here. Never call `createClient` elsewhere:
 * you'd end up with multiple clients fighting over the same auth session.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import 'react-native-url-polyfill/auto';

import { env } from '@/lib/env';

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
