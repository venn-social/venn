# Genre Clustering Pipeline

Data-driven genre discovery using semantic embeddings + Leiden community detection.

## Approach

1. **Embed** each media item (title, creator, year, overview) using [sentence-transformers](https://www.sbert.net/) (`all-mpnet-base-v2`, 768-dimensional embeddings)
2. **Graph** — build a graph of items where edges connect items with cosine similarity > 0.5
3. **Cluster** — run the [Leiden algorithm](https://leidenalg.readthedocs.io/) to partition the graph into communities
4. **Validate** — ensure clusters are evenly balanced (std dev of cluster sizes)
5. **Output** — JSON file with cluster metadata and grouped items

The result: ~30 semantic genres discovered from the data, not hand-curated.

## Setup

```bash
# Install dependencies
pip install -r scripts/genre-clustering/requirements.txt

# Confirm .env has SUPABASE_URL and SUPABASE_ANON_KEY
cat .env | grep SUPABASE
```

## Usage

### Test run (100 items)

```bash
cd scripts/genre-clustering
python cluster_genres.py --test
```

Outputs: `test_clustering_result.json`

### Full catalog

```bash
cd scripts/genre-clustering
python cluster_genres.py --full
```

Outputs: `full_clustering_result.json`

## Output format

```json
{
  "metadata": {
    "n_clusters": 28,
    "mean_cluster_size": 3.6,
    "std_dev": 2.1,
    "min_cluster_size": 1,
    "max_cluster_size": 12,
    "imbalance_ratio": 12.0
  },
  "clusters": {
    "0": [
      { "id": "uuid", "title": "...", "kind": "movie", "creator": "..." },
      ...
    ],
    "1": [ ... ]
  }
}
```

## Next steps

1. **Validate clusters:** Review the JSON output, ensure clusters are semantically coherent (e.g., cluster 0 is all sci-fi, cluster 1 is all romance, etc.)
2. **Tune resolution:** If clusters are too broad or too granular, adjust `resolution` in `cluster_with_leiden()` (line 97)
3. **Wire into schema:** Add a `genres` text[] field to the `media` table via migration, map cluster labels to cluster IDs
4. **GitHub Actions:** Create a scheduled job (weekly?) to re-embed and re-cluster new items, backfill the `genres` field

## Technical notes

- **Embedding model:** `all-mpnet-base-v2` is excellent for clustering (multi-lingual, 768-dim, 330M params). Pre-downloaded on first run; cached locally (~1.4GB).
- **Graph construction:** Only edges with cosine similarity > 0.5 to avoid a fully-connected graph (O(n²) edges).
- **Leiden algorithm:** Non-deterministic by default; seeded with `seed=42` for reproducibility.
- **Cluster balance:** Std dev < 3 is healthy; > 5 suggests over- or under-clustering.
