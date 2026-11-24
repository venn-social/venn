-- =============================================================================
-- 20261124100000_taste_scoring.sql — the hybrid scoring RPCs.
-- =============================================================================
-- Step 5 of docs/superpowers/specs/2026-11-17-taste-engine-design.md: score
-- candidates against a person's taste across every medium, using the
-- weighted feature similarity of §2 plus the collaborative term of §4.1, and
-- say why for every result.
--
-- Two RPCs, both `security invoker` (posts' RLS still decides what the
-- caller can see) and both rate-limited on one key ('taste_recs', 30/min):
--
--   taste_recommendations(_limit)  the full profile (§3.2): top-50 seeds,
--                                  positive and negative, recency-weighted.
--   because_you_loved(_limit)      the launch shelf (§3.4): one anchor — the
--                                  strongest recent Love, else Like — at most
--                                  ceil(_limit / 4) results per kind.
--
-- Everything else lives in `taste_internal`, a schema PostgREST does not
-- expose (supabase/config.toml lists only public and graphql_public). Its
-- functions are reachable from the two RPCs and from nowhere on the API, so
-- they need no rate limit of their own. Three of them are `security
-- definer`, because they read tables no client may read:
--
--   embedding_cosines / nearest_to_seeds  return ids and distances, never a
--                                         vector (§6).
--   pair_evidence                         returns the aggregate counts that
--                                         are already ≥ 3 by construction.
--
-- refresh_item_pair_evidence() rebuilds those counts from public accounts'
-- likes only. It is for the service role; scheduling it is a separate call.
--
-- Weights come from the active `taste_weights` row, never from code. A
-- feature missing on either side is ignored and the rest re-normalised, so
-- the embedding term contributes nothing until vectors exist (§7, step 4),
-- and the collaborative term is exactly zero with no evidence: α = 0 and
-- sim' = sim (§4.1).
--
-- Idempotent: safe to replay.
-- =============================================================================

create schema if not exists taste_internal;
revoke all on schema taste_internal from public;
-- The invoker RPCs run as the caller, so the caller needs to reach in here.
grant usage on schema taste_internal to authenticated;

-- -----------------------------------------------------------------------------
-- Small pure helpers.
-- -----------------------------------------------------------------------------

-- Role weights, §1.2. Cast beyond fifth billing carries no weight.
create or replace function taste_internal.role_weight(_role public.person_role, _billing smallint)
returns real
language sql
immutable
set search_path = ''
as $$
  select (case _role
    when 'director' then 1.0
    when 'author' then 1.0
    when 'primary_artist' then 1.0
    when 'tv_creator' then 1.0
    when 'composer' then 0.8
    when 'screenwriter' then 0.7
    when 'producer' then 0.7
    when 'cast' then case when _billing between 1 and 5 then 0.5 else 0 end
    when 'translator' then 0.2
    else 0
  end)::real;
$$;

create or replace function taste_internal.jaccard(_a text[], _b text[])
returns double precision
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(cardinality(_a), 0) = 0 and coalesce(cardinality(_b), 0) = 0 then null
    else (select count(*) from (select unnest(_a) intersect select unnest(_b)) i)::double precision
         / (select count(*) from (select unnest(_a) union select unnest(_b)) u)
  end;
$$;

create or replace function taste_internal.intersection(_a text[], _b text[])
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(x order by x), '{}') from (select unnest(_a) intersect select unnest(_b)) i(x);
$$;

-- A signal's weight (§3.1). Ratings are written as 5 / 3 / 1 by both clients
-- and both importers (Love / Like / Dislike); the bands below also place any
-- older half-step rating on the nearest side.
create or replace function taste_internal.signal_weight(_action public.post_action, _rating numeric)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select case
    when _rating >= 4.5 then 1.0
    when _rating >= 3 then 0.6
    when _rating is not null then -0.8
    when _action = 'saved' then 0.1
    else 0.2
  end;
$$;

create or replace function taste_internal.active_weights()
returns table (version int, weights jsonb, k real)
language sql
stable
set search_path = ''
as $$
  select w.version, w.weights, w.k
    from public.taste_weights w
   where w.active
   order by w.version desc
   limit 1;
$$;

-- -----------------------------------------------------------------------------
-- Definer helpers: the only way into embeddings and pair evidence.
-- -----------------------------------------------------------------------------

-- Cosine similarity between items in _a and items in _b. Only pairs embedded
-- by the same model at the same dimension are comparable.
create or replace function taste_internal.embedding_cosines(_a uuid[], _b uuid[])
returns table (a uuid, b uuid, cosine double precision)
language sql
stable
security definer
set search_path = ''
as $$
  select ea.media_id, eb.media_id,
         1 - (ea.embedding operator(extensions.<=>) eb.embedding)
    from public.media_embeddings ea
    join public.media_embeddings eb
      on eb.model = ea.model
     and extensions.vector_dims(eb.embedding) = extensions.vector_dims(ea.embedding)
   where ea.media_id = any(_a)
     and eb.media_id = any(_b)
     and ea.media_id <> eb.media_id;
$$;

-- The items nearest the weighted centroid of the positive seeds (§3.3, step
-- 1): the top _limit overall, plus the top 20 of every kind so a film-heavy
-- profile still surfaces books and albums. Brute force until the HNSW index
-- arrives with the embedding pass; nothing calls this before vectors exist.
create or replace function taste_internal.nearest_to_seeds(
  _seeds uuid[], _weights double precision[], _limit int, _exclude uuid[]
)
returns table (media_id uuid, distance double precision)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  _model text;
  _dims int;
  _centroid real[];
begin
  -- The space of the strongest seed that has a vector.
  select e.model, extensions.vector_dims(e.embedding)
    into _model, _dims
    from unnest(_seeds, _weights) s(id, w)
    join public.media_embeddings e on e.media_id = s.id
   where s.w > 0
   order by s.w desc
   limit 1;
  if _dims is null then
    return;
  end if;

  select array_agg(t.v order by t.i)
    into _centroid
    from (
      select u.i, sum(s.w * u.x)::real as v
        from unnest(_seeds, _weights) s(id, w)
        join public.media_embeddings e
          on e.media_id = s.id and e.model = _model
         and extensions.vector_dims(e.embedding) = _dims
       cross join lateral unnest(e.embedding::real[]) with ordinality u(x, i)
       where s.w > 0
       group by u.i
    ) t;

  return query
    with ranked as (
      select e.media_id,
             (e.embedding operator(extensions.<=>) _centroid::extensions.vector)::double precision as d,
             m.kind
        from public.media_embeddings e
        join public.media m on m.id = e.media_id
       where e.model = _model
         and extensions.vector_dims(e.embedding) = _dims
         and not (e.media_id = any(_exclude))
    ), numbered as (
      select r.media_id, r.d,
             row_number() over (order by r.d) as overall,
             row_number() over (partition by r.kind order by r.d) as within_kind
        from ranked r
    )
    select n.media_id, n.d from numbered n
     where n.overall <= _limit or n.within_kind <= 20;
end;
$$;

-- Collaborative evidence for every (a, b) asked about, in the caller's
-- orientation: n_a is always a's count.
create or replace function taste_internal.pair_evidence(_a uuid[], _b uuid[])
returns table (a uuid, b uuid, n_ab int, n_a int, n_b int)
language sql
stable
security definer
set search_path = ''
as $$
  select x.a, x.b, e.n_ab,
         case when e.a = x.a then e.n_a else e.n_b end,
         case when e.a = x.a then e.n_b else e.n_a end
    from (select sa.id as a, sb.id as b from unnest(_a) sa(id) cross join unnest(_b) sb(id)) x
    join public.item_pair_evidence e
      on e.a = least(x.a, x.b) and e.b = greatest(x.a, x.b);
$$;

-- -----------------------------------------------------------------------------
-- sim'(seed, candidate) with its explanation (§2, §2.1, §4.1).
-- -----------------------------------------------------------------------------
create or replace function taste_internal.pair_scores(_seeds uuid[], _candidates uuid[])
returns table (seed uuid, candidate uuid, sim double precision, why jsonb)
language sql
stable
set search_path = ''
-- The plan is wide enough that the planner's cost estimate triggers JIT,
-- and compiling it costs seconds against a query that runs in milliseconds.
set jit = off
as $$
  with w as (
    select a.weights, a.k from taste_internal.active_weights() a
  ),
  items as (
    select distinct x.id from unnest(_seeds || _candidates) x(id)
  ),
  pairs as (
    select distinct s.id as s, c.id as c
      from unnest(_seeds) s(id) cross join unnest(_candidates) c(id)
     where s.id <> c.id
  ),
  -- Taxonomy (§1.3): vectors are stored normalised, so the dot product over
  -- shared nodes is the cosine.
  tax_items as (
    select distinct t.media_id from public.media_taxonomy t where t.media_id in (select id from items)
  ),
  tax as (
    select p.s, p.c,
           sum(ts.weight * tc.weight)::double precision as score,
           (array_agg(n.slug order by ts.weight * tc.weight desc, n.slug))[1] as node,
           bool_or(n.family = 'era') as shared_era
      from pairs p
      join public.media_taxonomy ts on ts.media_id = p.s
      join public.media_taxonomy tc on tc.media_id = p.c and tc.node_id = ts.node_id
      join public.taxonomy_nodes n on n.id = ts.node_id
     group by p.s, p.c
  ),
  -- People (§1.2): weighted Jaccard, Σmin / (Σa + Σb − Σmin), each person
  -- weighted by their strongest role on the item.
  pw as (
    select mp.media_id, mp.person_id,
           max(taste_internal.role_weight(mp.role, mp.billing))::double precision as w,
           (array_agg(mp.role order by taste_internal.role_weight(mp.role, mp.billing) desc))[1] as role
      from public.media_people mp
     where mp.media_id in (select id from items)
     group by mp.media_id, mp.person_id
    having max(taste_internal.role_weight(mp.role, mp.billing)) > 0
  ),
  ptot as (
    select pw.media_id, sum(pw.w) as total from pw group by pw.media_id
  ),
  ppl as (
    select p.s, p.c,
           sum(least(a.w, b.w)) as inter,
           (array_agg(jsonb_build_object(
              'code', 'shared_person', 'person_id', a.person_id,
              'role_a', a.role, 'role_b', b.role)
            order by least(a.w, b.w) desc, a.person_id))[1] as obj
      from pairs p
      join pw a on a.media_id = p.s
      join pw b on b.media_id = p.c and b.person_id = a.person_id
     group by p.s, p.c
  ),
  emb as (
    select e.a as s, e.b as c, e.cosine
      from taste_internal.embedding_cosines(_seeds, _candidates) e
  ),
  ev as (
    select e.a as s, e.b as c, e.n_ab, e.n_a, e.n_b
      from taste_internal.pair_evidence(_seeds, _candidates) e
  ),
  feats as (
    select p.s, p.c,
      -- taxonomy
      case when p.s in (select media_id from tax_items) and p.c in (select media_id from tax_items)
           then coalesce(tax.score, 0) end as s_taxonomy,
      tax.node,
      -- vibe
      case when vs.media_id is not null and vc.media_id is not null then
        0.4 * (1 - (abs(vs.pace - vc.pace) + abs(vs.tone - vc.tone) + abs(vs.intensity - vc.intensity)) / 3.0)
        + 0.3 * coalesce(taste_internal.jaccard(vs.moods, vc.moods), 0)
        + 0.3 * coalesce(taste_internal.jaccard(vs.themes, vc.themes), 0)
      end as s_vibe,
      taste_internal.intersection(vs.moods, vc.moods) as moods,
      taste_internal.intersection(vs.themes, vc.themes) as themes,
      -- embedding: unrelated items sit near cosine 0.2, so rescale from there
      case when emb.cosine is not null then greatest(0, (emb.cosine - 0.2) / 0.8) end as s_embedding,
      -- people
      case when ts.total is not null and tc.total is not null
           then coalesce(ppl.inter, 0) / (ts.total + tc.total - coalesce(ppl.inter, 0)) end as s_people,
      ppl.obj as person,
      -- time
      case when fs.year is not null and fc.year is not null then
        least(1, exp(-abs(fs.year - fc.year) / 8.0) + case when coalesce(tax.shared_era, false) then 0.1 else 0 end)
      end as s_time,
      fs.year as year_a, fc.year as year_b,
      -- origin
      case
        when fs.language is not null and fc.language is not null
             and cardinality(fs.countries) > 0 and cardinality(fc.countries) > 0 then
          0.6 * (fs.language = fc.language)::int + 0.4 * taste_internal.jaccard(fs.countries, fc.countries)
        when fs.language is not null and fc.language is not null then (fs.language = fc.language)::int
        when cardinality(fs.countries) > 0 and cardinality(fc.countries) > 0 then
          taste_internal.jaccard(fs.countries, fc.countries)
      end as s_origin,
      case when fs.language = fc.language then fs.language end as language,
      taste_internal.intersection(fs.countries, fc.countries) as countries,
      -- commitment
      case when fs.commitment is not null and fc.commitment is not null
           then 1 - abs(fs.commitment - fc.commitment) end as s_commitment,
      -- sound (albums only in practice: no other kind has tags)
      case when cardinality(fs.sound_tags) > 0 and cardinality(fc.sound_tags) > 0
           then taste_internal.jaccard(fs.sound_tags, fc.sound_tags) end as s_sound,
      taste_internal.intersection(fs.sound_tags, fc.sound_tags) as sound,
      coalesce(ev.n_ab, 0) as n_ab,
      case when ev.n_ab > 0 then ev.n_ab / sqrt(ev.n_a::double precision * ev.n_b) end as collab
    from pairs p
    left join tax on tax.s = p.s and tax.c = p.c
    left join public.media_vibes vs on vs.media_id = p.s
    left join public.media_vibes vc on vc.media_id = p.c
    left join emb on emb.s = p.s and emb.c = p.c
    left join ptot ts on ts.media_id = p.s
    left join ptot tc on tc.media_id = p.c
    left join ppl on ppl.s = p.s and ppl.c = p.c
    left join public.media_features fs on fs.media_id = p.s
    left join public.media_features fc on fc.media_id = p.c
    left join ev on ev.s = p.s and ev.c = p.c
  ),
  -- Each feature's weighted contribution; null when the feature is absent
  -- on either side, so it drops out of the denominator too.
  contrib as (
    select f.*,
      (w.weights ->> 'taxonomy')::double precision * f.s_taxonomy as c_taxonomy,
      (w.weights ->> 'vibe')::double precision * f.s_vibe as c_vibe,
      (w.weights ->> 'embedding')::double precision * f.s_embedding as c_embedding,
      (w.weights ->> 'people')::double precision * f.s_people as c_people,
      (w.weights ->> 'time')::double precision * f.s_time as c_time,
      (w.weights ->> 'origin')::double precision * f.s_origin as c_origin,
      (w.weights ->> 'commitment')::double precision * f.s_commitment as c_commitment,
      (w.weights ->> 'sound')::double precision * f.s_sound as c_sound,
      (case when f.s_taxonomy is not null then (w.weights ->> 'taxonomy')::double precision else 0 end
       + case when f.s_vibe is not null then (w.weights ->> 'vibe')::double precision else 0 end
       + case when f.s_embedding is not null then (w.weights ->> 'embedding')::double precision else 0 end
       + case when f.s_people is not null then (w.weights ->> 'people')::double precision else 0 end
       + case when f.s_time is not null then (w.weights ->> 'time')::double precision else 0 end
       + case when f.s_origin is not null then (w.weights ->> 'origin')::double precision else 0 end
       + case when f.s_commitment is not null then (w.weights ->> 'commitment')::double precision else 0 end
       + case when f.s_sound is not null then (w.weights ->> 'sound')::double precision else 0 end
      ) as denominator,
      f.n_ab / (f.n_ab + w.k)::double precision as alpha
    from feats f cross join w
  ),
  scored as (
    select c.*,
      case when c.denominator > 0 then
        (coalesce(c.c_taxonomy, 0) + coalesce(c.c_vibe, 0) + coalesce(c.c_embedding, 0)
         + coalesce(c.c_people, 0) + coalesce(c.c_time, 0) + coalesce(c.c_origin, 0)
         + coalesce(c.c_commitment, 0) + coalesce(c.c_sound, 0)) / c.denominator
      end as feature_sim
    from contrib c
  )
  select sc.s, sc.c,
    -- sim' = (1 − α)·sim + α·collab; with no evidence α = 0 and this is sim.
    case
      when sc.n_ab > 0 then (1 - sc.alpha) * coalesce(sc.feature_sim, 0) + sc.alpha * sc.collab
      else sc.feature_sim
    end as sim,
    coalesce(
      -- The two strongest specific reasons…
      (select jsonb_agg(r.obj order by r.contribution desc)
         from (select v.obj, v.contribution
                 from (values
                   (sc.c_taxonomy, jsonb_build_object('code', 'shared_node', 'node', sc.node)),
                   (sc.c_people, sc.person),
                   (sc.c_vibe, jsonb_build_object('code', 'shared_vibe', 'moods', to_jsonb(sc.moods),
                                                  'themes', to_jsonb(sc.themes))),
                   (sc.c_time, jsonb_build_object('code', 'same_era', 'year_a', sc.year_a, 'year_b', sc.year_b)),
                   (sc.c_origin, jsonb_build_object('code', 'same_origin', 'language', sc.language,
                                                    'countries', to_jsonb(sc.countries))),
                   (sc.c_commitment, jsonb_build_object('code', 'similar_length')),
                   (sc.c_sound, jsonb_build_object('code', 'shared_sound', 'tags', to_jsonb(sc.sound)))
                 ) v(contribution, obj)
                where v.contribution > 0 and v.obj is not null
                order by v.contribution desc
                limit 2) r),
      -- …and only when nothing specific scored, the two generic ones (§2.1).
      (select jsonb_agg(r.obj order by r.contribution desc)
         from (values
                 (sc.c_embedding, jsonb_build_object('code', 'embedding_close')),
                 (sc.alpha * sc.collab, jsonb_build_object('code', 'loved_by_similar'))
              ) r(contribution, obj)
        where r.contribution > 0),
      '[]'::jsonb
    ) as why
  from scored sc;
$$;

-- -----------------------------------------------------------------------------
-- Seeds and candidates.
-- -----------------------------------------------------------------------------

-- The caller's top 50 signals by |weight × decay| (§3.1, §3.2). Half-life one
-- year on posts.created_at — imports are backdated, so old taste counts less.
create or replace function taste_internal.viewer_seeds(_viewer uuid)
returns table (media_id uuid, weight double precision, rating numeric, created_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select p.media_id,
         taste_internal.signal_weight(p.action, p.rating)
           * power(0.5, greatest(extract(epoch from now() - p.created_at), 0) / 86400.0 / 365.0),
         p.rating,
         p.created_at
    from public.posts p
   where p.author_id = _viewer
   order by abs(taste_internal.signal_weight(p.action, p.rating)
                * power(0.5, greatest(extract(epoch from now() - p.created_at), 0) / 86400.0 / 365.0)) desc,
            p.created_at desc
   limit 50;
$$;

-- Candidate generation (§3.3): nearest to the taste centroid, plus items
-- sharing a person or a taxonomy node with a positive seed, each with a
-- per-kind floor of 20. Never anything the caller has already touched.
create or replace function taste_internal.candidates(
  _seeds uuid[], _weights double precision[], _exclude uuid[]
)
returns table (media_id uuid)
language sql
stable
set search_path = ''
as $$
  with positive as (
    select s.id from unnest(_seeds, _weights) s(id, w) where s.w > 0
  ),
  overlap as (
    select x.media_id, count(*) as shared
      from (
        select mp2.media_id
          from public.media_people mp1
          join public.media_people mp2 on mp2.person_id = mp1.person_id
         where mp1.media_id in (select id from positive)
        union all
        select t2.media_id
          from public.media_taxonomy t1
          join public.media_taxonomy t2 on t2.node_id = t1.node_id
         where t1.media_id in (select id from positive)
      ) x
     where not (x.media_id = any(_exclude))
     group by x.media_id
  ),
  overlap_ranked as (
    select o.media_id,
           row_number() over (order by o.shared desc, o.media_id) as overall,
           row_number() over (partition by m.kind order by o.shared desc, o.media_id) as within_kind
      from overlap o
      join public.media m on m.id = o.media_id
  )
  select r.media_id from overlap_ranked r where r.overall <= 200 or r.within_kind <= 20
  union
  select n.media_id
    from taste_internal.nearest_to_seeds(_seeds, _weights, 300, _exclude) n;
$$;

-- -----------------------------------------------------------------------------
-- The RPCs.
-- -----------------------------------------------------------------------------
create or replace function public.taste_recommendations(_limit int default 30)
returns table (
  media_id uuid,
  kind public.media_kind,
  score double precision,
  because_of uuid,
  why jsonb,
  weights_version int
)
language plpgsql
volatile -- rl_check writes
security invoker
set search_path = ''
as $$
#variable_conflict use_column
declare
  _viewer uuid := (select auth.uid());
  _seed_ids uuid[];
  _seed_w double precision[];
  _norm double precision;
  _seen uuid[];
  _candidates uuid[];
  _version int;
begin
  if _viewer is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  if not public.rl_check('taste_recs:' || _viewer::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  _limit := least(greatest(coalesce(_limit, 30), 1), 100);

  select array_agg(s.media_id order by s.media_id), array_agg(s.weight order by s.media_id),
         sum(abs(s.weight))
    into _seed_ids, _seed_w, _norm
    from taste_internal.viewer_seeds(_viewer) s;
  if _seed_ids is null or _norm = 0 then
    return;
  end if;

  select coalesce(array_agg(distinct p.media_id), '{}') into _seen
    from public.posts p where p.author_id = _viewer;
  select coalesce(array_agg(c.media_id), '{}') into _candidates
    from taste_internal.candidates(_seed_ids, _seed_w, _seen) c;
  select a.version into _version from taste_internal.active_weights() a;

  -- score(c) = Σ wᵢ·sim'(seedᵢ, c) / Σ |wᵢ|. Negative seeds subtract, which
  -- is how a dislike pushes its near neighbours down (§3.2).
  return query
    with s as (
      select x.id, x.w from unnest(_seed_ids, _seed_w) x(id, w)
    ),
    ps as (
      select p.seed, p.candidate, p.sim, p.why, s.w
        from taste_internal.pair_scores(_seed_ids, _candidates) p
        join s on s.id = p.seed
       where p.sim is not null
    ),
    agg as (
      select ps.candidate,
             sum(ps.w * ps.sim) / _norm as score,
             (array_agg(ps.seed order by ps.w * ps.sim desc))[1] as because_of,
             (array_agg(ps.why order by ps.w * ps.sim desc))[1] as why
        from ps
       group by ps.candidate
    )
    select a.candidate, m.kind, a.score, a.because_of, a.why, _version
      from agg a
      join public.media m on m.id = a.candidate
     where a.score > 0 and jsonb_array_length(a.why) > 0
     order by a.score desc, a.candidate
     limit _limit;
end;
$$;

create or replace function public.because_you_loved(_limit int default 8)
returns table (
  anchor_media_id uuid,
  media_id uuid,
  kind public.media_kind,
  score double precision,
  why jsonb,
  weights_version int,
  rank int
)
language plpgsql
volatile -- rl_check writes
security invoker
set search_path = ''
as $$
#variable_conflict use_column
declare
  _viewer uuid := (select auth.uid());
  _anchor uuid;
  _seen uuid[];
  _candidates uuid[];
  _version int;
  _per_kind int;
begin
  if _viewer is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  if not public.rl_check('taste_recs:' || _viewer::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  _limit := least(greatest(coalesce(_limit, 8), 1), 40);
  -- The spec's "at most 2 per kind in the top 8", scaled with the shelf.
  _per_kind := greatest(2, ceil(_limit / 4.0)::int);

  -- The strongest recent Love; failing that, the strongest Like; failing
  -- that, no shelf (§3.4).
  select s.media_id into _anchor
    from taste_internal.viewer_seeds(_viewer) s
   where s.rating >= 3
   order by (s.rating >= 4.5) desc, s.weight desc, s.created_at desc
   limit 1;
  if _anchor is null then
    return;
  end if;

  select coalesce(array_agg(distinct p.media_id), '{}') into _seen
    from public.posts p where p.author_id = _viewer;
  select coalesce(array_agg(c.media_id), '{}') into _candidates
    from taste_internal.candidates(array[_anchor], array[1.0::double precision], _seen) c;
  select a.version into _version from taste_internal.active_weights() a;

  return query
    with ranked as (
      select p.candidate, m.kind, p.sim, p.why,
             row_number() over (partition by m.kind order by p.sim desc, p.candidate) as within_kind
        from taste_internal.pair_scores(array[_anchor], _candidates) p
        join public.media m on m.id = p.candidate
       where p.sim > 0 and jsonb_array_length(p.why) > 0
    )
    select _anchor, r.candidate, r.kind, r.sim, r.why, _version,
           (row_number() over (order by r.sim desc, r.candidate))::int
      from ranked r
     where r.within_kind <= _per_kind
     order by r.sim desc, r.candidate
     limit _limit;
end;
$$;

-- -----------------------------------------------------------------------------
-- Collaborative evidence (§4.1).
-- -----------------------------------------------------------------------------
-- Liked = Like or Love. Only public accounts count: a private account's
-- taste never leaves the circle it chose, even as an aggregate. A pair is
-- kept only at n_ab ≥ 3, so no row can single out one person's taste.
-- Rebuilt whole each run, in one statement, so readers never see a half-
-- written table.
create or replace function taste_internal.refresh_item_pair_evidence()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  _written int;
begin
  delete from public.item_pair_evidence;
  with likes as (
    select distinct p.author_id, p.media_id
      from public.posts p
      join public.profiles pr on pr.id = p.author_id
     where pr.is_private = false
       and p.rating >= 3
  ),
  counts as (
    select l.media_id, count(*)::int as n from likes l group by l.media_id
  ),
  pairs as (
    select l1.media_id as a, l2.media_id as b, count(*)::int as n_ab
      from likes l1
      join likes l2 on l2.author_id = l1.author_id and l2.media_id > l1.media_id
     group by l1.media_id, l2.media_id
    having count(*) >= 3
  )
  insert into public.item_pair_evidence (a, b, n_ab, n_a, n_b)
  select p.a, p.b, p.n_ab, ca.n, cb.n
    from pairs p
    join counts ca on ca.media_id = p.a
    join counts cb on cb.media_id = p.b;
  get diagnostics _written = row_count;
  return _written;
end;
$$;

-- -----------------------------------------------------------------------------
-- Grants.
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema taste_internal from public, anon;
grant execute on function
  taste_internal.role_weight(public.person_role, smallint),
  taste_internal.jaccard(text[], text[]),
  taste_internal.intersection(text[], text[]),
  taste_internal.signal_weight(public.post_action, numeric),
  taste_internal.active_weights(),
  taste_internal.embedding_cosines(uuid[], uuid[]),
  taste_internal.nearest_to_seeds(uuid[], double precision[], int, uuid[]),
  taste_internal.pair_evidence(uuid[], uuid[]),
  taste_internal.pair_scores(uuid[], uuid[]),
  taste_internal.viewer_seeds(uuid),
  taste_internal.candidates(uuid[], double precision[], uuid[])
  to authenticated;
-- The refresh writes on everyone's behalf: service role only.
revoke execute on function taste_internal.refresh_item_pair_evidence() from authenticated;

revoke execute on function public.taste_recommendations(int) from public, anon;
grant execute on function public.taste_recommendations(int) to authenticated;
revoke execute on function public.because_you_loved(int) from public, anon;
grant execute on function public.because_you_loved(int) to authenticated;
