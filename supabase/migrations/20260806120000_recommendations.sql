-- =============================================================================
-- 20260806120000_recommendations.sql — the venn-data half of recommendations.
-- =============================================================================
-- Two tiers come from our own data: people whose taste matches yours, and
-- people you follow. The other two (similar-to-what-you-loved, trending)
-- need external catalogs and are fetched per client — Postgres cannot call
-- TMDB.
--
-- Both functions are `security invoker` on purpose. Recommendations derive
-- from other people's logs, so the privacy boundary is load-bearing: RLS
-- already hides a private account's posts from non-followers, and running
-- as the caller means that protection applies here for free rather than
-- being re-implemented (and eventually got wrong).
--
-- Idempotent: safe to replay.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- similar_users(_limit) — who shares your taste.
-- -----------------------------------------------------------------------------
-- Jaccard similarity over consumed sets, reusing the definition
-- compute_overlap established: consumed means logged or rated. A watchlist
-- entry is an intention, not a verdict, so `saved` is excluded from both
-- sides.
create or replace function public.similar_users(_limit int default 20)
returns table (
  user_id uuid,
  similarity numeric,
  shared_count bigint
)
language sql
security invoker
stable
set search_path = ''
as $$
  with viewer_media as (
    select distinct p.media_id
      from public.posts p
     where p.author_id = (select auth.uid())
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  ),
  viewer_total as (
    select count(*)::bigint as n from viewer_media
  ),
  others as (
    select distinct p.author_id, p.media_id
      from public.posts p
     where p.author_id <> (select auth.uid())
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  ),
  scored as (
    select o.author_id,
           count(*) filter (where v.media_id is not null)::bigint as shared,
           count(*)::bigint as other_total
      from others o
      left join viewer_media v on v.media_id = o.media_id
     group by o.author_id
  )
  select s.author_id as user_id,
         round(
           s.shared::numeric
           / nullif((select n from viewer_total) + s.other_total - s.shared, 0),
           4
         ) as similarity,
         s.shared as shared_count
    from scored s
   where s.shared > 0
   order by similarity desc nulls last, s.shared desc
   limit _limit;
$$;

revoke execute on function public.similar_users(int) from public, anon;
grant execute on function public.similar_users(int) to authenticated;

-- -----------------------------------------------------------------------------
-- recommendation_feed(_seed_limit, _per_section) — everything SQL can know.
-- -----------------------------------------------------------------------------
-- Returns one jsonb document rather than several result sets: the client
-- needs all of it to assemble a single screen, and one round trip beats
-- four.
--
-- Empty sections and empty seeds are normal, not errors. A brand-new user
-- gets empty everything and sees only the client's trending shelf.
create or replace function public.recommendation_feed(
  _seed_limit int default 5,
  _per_section int default 12
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = ''
as $$
declare
  viewer uuid := (select auth.uid());
  seen uuid[];
  twins uuid[];
  twin_items jsonb;
  followed_items jsonb;
  seed_items jsonb;
  excluded_keys jsonb;
begin
  if viewer is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- Every media row the viewer has touched at all — consumed, rated, or
  -- put on their watchlist. One array, applied to every tier: recommending
  -- something already on your watchlist is useless, and recommending
  -- something you disliked is worse.
  select coalesce(array_agg(distinct p.media_id), '{}')
    into seen
    from public.posts p
   where p.author_id = viewer;

  select coalesce(array_agg(su.user_id), '{}')
    into twins
    from public.similar_users(20) su;

  -- Tier 1 — what the taste twins loved, most-shared first.
  select coalesce(jsonb_agg(x.media order by x.votes desc, x.newest desc), '[]'::jsonb)
    into twin_items
    from (
      select to_jsonb(m) as media,
             count(*) as votes,
             max(p.created_at) as newest
        from public.posts p
        join public.media m on m.id = p.media_id
       where p.author_id = any(twins)
         and p.rating >= 3
         and not (p.media_id = any(seen))
       group by m.id
       order by votes desc, newest desc
       limit _per_section
    ) x;

  -- Tier 2 — what the people you follow loved, newest first. Only accepted
  -- follows: a pending request to a private account grants nothing.
  select coalesce(jsonb_agg(x.media order by x.newest desc), '[]'::jsonb)
    into followed_items
    from (
      select to_jsonb(m) as media,
             max(p.created_at) as newest
        from public.posts p
        join public.media m on m.id = p.media_id
        join public.follows f on f.followee_id = p.author_id
       where f.follower_id = viewer
         and f.status = 'accepted'
         and p.rating >= 3
         and not (p.media_id = any(seen))
       group by m.id
       order by newest desc
       limit _per_section
    ) x;

  -- Seeds for tier 3. Only rows with an external identity: a hand-typed
  -- entry has no catalog to ask for similar titles.
  select coalesce(jsonb_agg(s.obj), '[]'::jsonb)
    into seed_items
    from (
      select jsonb_build_object(
               'media_id', m.id,
               'title', m.title,
               'kind', m.kind,
               'external_source', m.external_source,
               'external_id', m.external_id,
               'rating', p.rating
             ) as obj
        from public.posts p
        join public.media m on m.id = p.media_id
       where p.author_id = viewer
         and p.rating >= 3
         and m.external_source is not null
         and m.external_id is not null
       order by p.rating desc, p.created_at desc
       limit _seed_limit
    ) s;

  -- The exclusion list the client filters catalog results through. Keyed
  -- source:kind:id — kind matters because TMDB numbers movies and TV
  -- independently. Capped at 500: past that the payload costs more than
  -- the occasional duplicate it prevents.
  select coalesce(jsonb_agg(e.obj), '[]'::jsonb)
    into excluded_keys
    from (
      select jsonb_build_object(
               'source', m.external_source,
               'kind', m.kind,
               'id', m.external_id
             ) as obj
        from public.posts p
        join public.media m on m.id = p.media_id
       where p.author_id = viewer
         and m.external_source is not null
         and m.external_id is not null
       group by m.external_source, m.kind, m.external_id
       order by max(p.created_at) desc
       limit 500
    ) e;

  return jsonb_build_object(
    'sections', (
      select coalesce(jsonb_agg(s.obj order by s.ord), '[]'::jsonb)
        from (
          select 1 as ord,
                 jsonb_build_object('source', 'taste_twins', 'items', twin_items) as obj
           where jsonb_array_length(twin_items) > 0
          union all
          select 2,
                 jsonb_build_object('source', 'followed', 'items', followed_items)
           where jsonb_array_length(followed_items) > 0
        ) s
    ),
    'seeds', seed_items,
    'excluded', excluded_keys
  );
end;
$$;

revoke execute on function public.recommendation_feed(int, int) from public, anon;
grant execute on function public.recommendation_feed(int, int) to authenticated;
