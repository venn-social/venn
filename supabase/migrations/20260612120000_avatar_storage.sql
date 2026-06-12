-- =============================================================================
-- 20260612120000_avatar_storage.sql — avatars bucket + owner-scoped writes.
-- =============================================================================
-- Profile avatars live in Storage under `avatars/<user-id>/avatar.jpg`.
-- The bucket is public-read (profiles are public per the product vision;
-- avatar URLs are stored on the profile row and fetched by anyone), but
-- writes are folder-scoped: you can only create/replace/delete objects
-- inside the folder named after your own auth uid.
--
-- Idempotent: safe to replay.
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists avatars_read_all on storage.objects;
create policy avatars_read_all
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own_folder on storage.objects;
create policy avatars_insert_own_folder
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own_folder on storage.objects;
create policy avatars_update_own_folder
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own_folder on storage.objects;
create policy avatars_delete_own_folder
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
