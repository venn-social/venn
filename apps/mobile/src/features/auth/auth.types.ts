import type { Session, User } from '@supabase/supabase-js';

export interface AuthContextValue {
  readonly user: User | null;
  readonly session: Session | null;
  readonly isLoading: boolean;
}
