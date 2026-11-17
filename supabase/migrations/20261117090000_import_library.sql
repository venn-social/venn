-- =============================================================================
-- 20261117090000_import_library.sql — bulk import from Letterboxd/Goodreads.
-- =============================================================================
-- A Letterboxd or Goodreads export carries hundreds of titles. Two things in
-- the normal one-post-at-a-time path make that unworkable:
--
--   1. `posts_rate_limit` (20260804180000) caps an author at 30 inserts a
--      minute. Right for a person tapping "log", wrong for a 600-row import:
--      it would take twenty minutes of paced requests.
--   2. Every insert lands at now(), so an import would push hundreds of
--      "just logged" posts into friends' feeds at once.
--
-- `import_library` takes one batch of already-matched catalog items and
-- writes them in a single call:
--
--   * Rate-limited once per call ('library_import', 30 an hour, at most 200
--     items each), so the ceiling is still enforced at the API boundary —
--     it is just counted per batch rather than per row.
--   * Idempotent. Media is keyed on (external_source, external_id) and posts
--     on (author_id, media_id), both with ON CONFLICT DO NOTHING. Re-running
--     an import adds nothing, and never overwrites a rating or caption the
--     person has set in venn since.
--   * Backdated. Each post keeps the date from the export (clamped to
--     1900..now()), so imported history sits in the past instead of
--     flooding the feed.
--
-- `security invoker`: posts' and media's own RLS still decide what the caller
-- may write. The per-row trigger is skipped for this call only, through a
-- transaction-local setting that names the caller. PostgREST gives clients no
-- way to run set_config, and the trigger also requires the setting to equal
-- the row's author, so the bypass cannot be borrowed for anyone else's rows.
--
-- Idempotent: safe to replay.
-- =============================================================================

create or replace function public.enforce_post_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- import_library has already spent a rate-limit allowance for the whole
  -- batch; counting each of its rows again would refuse any real import.
  if current_setting('venn.bulk_import_author', true) = new.author_id::text then
    return new;
  end if;

  if not public.rl_check('create_post:' || new.author_id::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

create or replace function public.import_library(_items jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  _caller uuid := auth.uid();
  _item jsonb;
  _media_id uuid;
  _action public.post_action;
  _rating numeric;
  _source text;
  _external_id text;
  _year int;
  _cover text;
  _consumed_at timestamptz;
  _inserted int;
  _imported int := 0;
  _skipped int := 0;
begin
  if _caller is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if jsonb_typeof(_items) is distinct from 'array'
     or jsonb_array_length(_items) = 0
     or jsonb_array_length(_items) > 200 then
    raise exception 'import batch must hold 1 to 200 items' using errcode = '22023';
  end if;

  if not public.rl_check('library_import:' || _caller::text, 30, interval '1 hour') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;

  perform set_config('venn.bulk_import_author', _caller::text, true);

  for _item in select value from jsonb_array_elements(_items) loop
    _source := _item ->> 'external_source';
    _external_id := btrim(_item ->> 'external_id');
    if _source not in ('tmdb', 'openlibrary', 'musicbrainz')
       or _external_id is null
       or length(_external_id) not between 1 and 64 then
      raise exception 'import item needs a catalog source and id' using errcode = '22023';
    end if;

    _action := (_item ->> 'action')::public.post_action;
    _rating := (_item ->> 'rating')::numeric;
    -- Mirrors both clients: 'rated' always carries one of the three
    -- sentiments, and nothing else carries a rating at all.
    if (_action = 'rated') <> (_rating is not null)
       or (_rating is not null and _rating not in (1, 3, 5)) then
      raise exception 'import item rating does not match its action' using errcode = '22023';
    end if;

    _year := (_item ->> 'year')::int;
    if _year not between 1800 and 2200 then
      _year := null;
    end if;

    _cover := _item ->> 'cover_url';
    if _cover is not null and _cover not like 'https://%' then
      _cover := null;
    end if;

    insert into public.media (kind, title, year, primary_creator, cover_url, external_source, external_id)
    values (
      (_item ->> 'kind')::public.media_kind,
      left(btrim(_item ->> 'title'), 200),
      _year,
      nullif(left(btrim(_item ->> 'primary_creator'), 120), ''),
      _cover,
      _source,
      _external_id
    )
    on conflict (external_source, external_id)
      where external_source is not null and external_id is not null
      do nothing;

    select id into _media_id
      from public.media
     where external_source = _source
       and external_id = _external_id;

    _consumed_at := least(
      greatest(coalesce((_item ->> 'consumed_at')::timestamptz, now()), timestamptz '1900-01-01'),
      now()
    );

    insert into public.posts (author_id, media_id, action, rating, created_at)
    values (_caller, _media_id, _action, _rating, _consumed_at)
    on conflict (author_id, media_id) do nothing;

    get diagnostics _inserted = row_count;
    if _inserted = 1 then
      _imported := _imported + 1;
    else
      _skipped := _skipped + 1;
    end if;
  end loop;

  return jsonb_build_object('imported', _imported, 'skipped', _skipped);
end;
$$;

revoke execute on function public.import_library(jsonb) from public, anon;
grant execute on function public.import_library(jsonb) to authenticated;
