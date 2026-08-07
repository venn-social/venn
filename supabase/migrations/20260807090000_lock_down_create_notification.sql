-- =============================================================================
-- 20260807090000_lock_down_create_notification.sql
-- =============================================================================
-- `create_notification` was reachable by the `anon` role over REST.
--
-- It is `security definer` (so it bypasses RLS), returns void rather than
-- trigger (so PostgREST will happily call it), and takes both the
-- recipient and the actor as arguments. Anyone holding the anon key — which
-- ships in the web bundle and the iOS app, and is public by design — could
-- POST to /rest/v1/rpc/create_notification and forge a notification to any
-- user, from any actor, of any kind.
--
-- The notifications migration tried to prevent this with:
--
--     revoke execute on function public.create_notification(...) from public;
--
-- That is not enough on Supabase. `anon` and `authenticated` hold their own
-- explicit grants from `alter default privileges`, and revoking from
-- PUBLIC leaves those untouched. The ACL after that statement still read
-- `anon=X/postgres | authenticated=X/postgres`. Revokes here name the roles
-- directly, which is what the recommendations and list-reorder migrations
-- already do.
--
-- Nothing calls this function from a client — it exists only for the
-- notify_* triggers, and a `security definer` function invoked by a trigger
-- runs as its owner and needs no grant at all. So this removes the reach
-- without removing any capability.
--
-- Idempotent: safe to replay.
-- =============================================================================

revoke execute on function public.create_notification(uuid, uuid, text, uuid, uuid)
  from public, anon, authenticated;

-- The paired reader/writer RPCs are meant for signed-in users only. They
-- were revoked from PUBLIC the same way, so re-state them against the roles
-- to be certain `anon` cannot read another account's unread count or mark
-- someone else's notifications read.
revoke execute on function public.unread_notification_count() from public, anon;
grant execute on function public.unread_notification_count() to authenticated;

revoke execute on function public.mark_notifications_read() from public, anon;
grant execute on function public.mark_notifications_read() to authenticated;
