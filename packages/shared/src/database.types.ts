/**
 * database.types.ts — TypeScript types generated from the Supabase schema.
 *
 * This file is the SOURCE OF TRUTH for backend table shapes in TypeScript.
 * Do NOT hand-edit it. Regenerate with:
 *
 *   npm run db:types
 *
 * That command requires that the project is linked (`npx supabase link
 * --project-ref <ref>`) and you have a Supabase access token in `.env`.
 *
 * Until the first regeneration, this file is a placeholder. The first PR
 * that touches Supabase data will run `db:types` and replace this file
 * with real generated types.
 */

export type Database = {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
