#!/usr/bin/env python3
"""
Backfill the media table with genre cluster IDs from a clustering result JSON.

Usage:
    python backfill_genres.py test_clustering_result.json    # Load test results
    python backfill_genres.py full_clustering_result.json    # Load full catalog results
"""

import json
import sys
import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)


def backfill_genres(result_file: str):
    """Load clustering results and backfill the media table."""
    print(f"Loading clustering results from {result_file}...")

    if not os.path.exists(result_file):
        print(f"Error: {result_file} not found")
        sys.exit(1)

    with open(result_file, "r") as f:
        results = json.load(f)

    metadata = results.get("metadata", {})
    clusters = results.get("clusters", {})

    print(f"  Found {metadata.get('n_clusters')} clusters")

    # Build a lookup: media_id → cluster_id
    media_to_clusters = {}
    for cluster_id, items in clusters.items():
        for item in items:
            media_id = item["id"]
            if media_id not in media_to_clusters:
                media_to_clusters[media_id] = []
            media_to_clusters[media_id].append(int(cluster_id))

    print(f"  Backfilling {len(media_to_clusters)} media items...")

    # Batch upsert: for each media item, update genres array
    for media_id, cluster_ids in media_to_clusters.items():
        try:
            supabase.table("media").update({"genres": cluster_ids}).eq("id", media_id).execute()
        except Exception as e:
            print(f"  Error updating {media_id}: {e}")

    print(f"✓ Backfilled {len(media_to_clusters)} media items with genres")
    print(f"  Total clusters discovered: {metadata.get('n_clusters')}")
    print(f"  Cluster balance (std dev): {metadata.get('std_dev'):.2f}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python backfill_genres.py <clustering_result.json>")
        sys.exit(1)

    result_file = sys.argv[1]
    backfill_genres(result_file)
