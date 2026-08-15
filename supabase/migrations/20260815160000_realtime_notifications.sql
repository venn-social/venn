-- =============================================================================
-- 20260815160000_realtime_notifications.sql — make the badge live.
-- =============================================================================
-- The unread badge refreshes when the app shell appears, so a notification
-- that lands while someone is reading their feed goes unannounced until they
-- navigate. Supabase Realtime was available and unused.
--
-- Realtime only delivers for tables in the `supabase_realtime` publication,
-- and that publication is currently empty, so subscribing without this
-- changes nothing at all — the client would connect, wait, and never hear
-- anything.
--
-- Safe to expose. Realtime applies RLS to `postgres_changes` for an
-- authenticated client, and `notifications_select_own` already scopes rows to
-- `auth.uid() = recipient_id`, so each person is delivered only their own
-- notifications. This adds no read path that a plain SELECT did not already
-- allow.
--
-- REPLICA IDENTITY FULL so UPDATE and DELETE payloads carry the old row.
-- Without it Postgres sends only the primary key for those, and RLS cannot
-- evaluate `recipient_id` on a row it was not given — the events would be
-- dropped rather than filtered, and marking something read elsewhere would
-- silently fail to reach other sessions. The table is small and short-lived,
-- so the extra WAL is not a concern here.
--
-- Idempotent: replaying finds the table already published and does nothing.
-- =============================================================================

alter table public.notifications replica identity full;

do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;
