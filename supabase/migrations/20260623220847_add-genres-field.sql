-- Add genres field to media table for semantic clustering results
-- `genres` stores cluster IDs (0-30) derived from Leiden community detection
-- on media embeddings (title, creator, year, kind via sentence-transformers).
-- Populated by the genre-clustering pipeline (scripts/genre-clustering/cluster_genres.py)
-- and backfilled weekly via GitHub Actions.

alter table public.media
  add column genres integer[] default array[]::integer[];

comment on column public.media.genres is
  'Semantic genre cluster IDs (0-30) from Leiden algorithm on embedding-space similarity. '
  'Populated by scripts/genre-clustering/cluster_genres.py and backfilled weekly via Actions.';
