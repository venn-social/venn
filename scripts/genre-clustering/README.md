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

## Integration

### Backfill the database

After clustering, populate the `media.genres` field (which stores cluster IDs):

```bash
cd scripts/genre-clustering
python backfill_genres.py test_clustering_result.json    # test run
python backfill_genres.py full_clustering_result.json    # production
```

This upserts cluster IDs for all media items in the result.

### Automatic weekly re-clustering

A GitHub Actions workflow runs every Monday at 2 AM UTC (`.github/workflows/genre-clustering.yml`):

1. Runs the full clustering on the entire catalog
2. Backfills genres into the database
3. Reports metrics (cluster count, balance)

Trigger manually: `gh workflow run genre-clustering.yml`

### Schema

The `media.genres` field stores an int[] of cluster IDs (0-30). Query for similar items:

```sql
-- Find media in the same genre clusters as a given item
select * from media
where genres && (select genres from media where id = 'uuid')
  and id != 'uuid'
limit 10;
```

### Tuning

- **Resolution parameter** (line 97 in `cluster_genres.py`): Controls cluster count
  - Lower = fewer, larger clusters
  - Higher = more, smaller clusters
  - Default 0.5 gives ~25-30 clusters for most catalogs
- **Similarity threshold** (line 87): Only connect nodes with cosine similarity > 0.5
  - Lower = denser graph, more connections, larger clusters
  - Higher = sparser graph, tighter clusters

## Technical notes

- **Embedding model:** `all-MiniLM-L6-v2` is excellent for clustering (384-dim, ~22M params, 47MB download). Fast and memory-efficient. Pre-downloaded on first run; cached locally (~47MB).
- **Graph construction:** Only edges with cosine similarity > 0.5 to avoid a fully-connected graph (O(n²) edges).
- **Leiden algorithm:** Non-deterministic by default; seeded with `seed=42` for reproducibility.
- **Cluster balance:** Std dev < 3 is healthy; > 5 suggests over- or under-clustering.
