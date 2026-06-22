#!/usr/bin/env python3
"""
Genre clustering pipeline: embed media items and cluster them into ~30 semantic genres.

Usage:
    python cluster_genres.py --test        # Run on a small test set (100 items)
    python cluster_genres.py --full        # Run on the full catalog
    python cluster_genres.py --validate    # Validate an existing clustering result
"""

import os
import json
import numpy as np
from typing import Optional
from pathlib import Path
import argparse

from sentence_transformers import SentenceTransformer
import leidenalg as la
from igraph import Graph
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

# Initialize Supabase client
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)

# Load embedding model once
print("Loading embedding model...")
model = SentenceTransformer("all-mpnet-base-v2")  # 768-dim, excellent for clustering

def fetch_media(limit: Optional[int] = None) -> list[dict]:
    """Fetch media items from Supabase."""
    print(f"Fetching media from Supabase{'...' if limit is None else f' (limit {limit})...'}")

    query = supabase.table("media").select(
        "id, kind, title, primary_creator, year, overview, external_source"
    )

    if limit:
        query = query.limit(limit)

    response = query.execute()
    items = response.data if response.data else []
    print(f"  Fetched {len(items)} items")
    return items

def embed_items(items: list[dict]) -> tuple[list[dict], np.ndarray]:
    """Embed media items using sentence-transformers."""
    print(f"Embedding {len(items)} items...")

    # Build text representation: "title by creator (year) — kind: overview"
    texts = []
    for item in items:
        parts = [item.get("title", "")]
        if item.get("primary_creator"):
            parts.append(f"by {item['primary_creator']}")
        if item.get("year"):
            parts.append(f"({item['year']})")

        text = " ".join(parts)
        if item.get("overview"):
            text += f" — {item['overview'][:200]}"  # Truncate long overviews
        texts.append(text)

    embeddings = model.encode(texts, show_progress_bar=True)
    print(f"  Embedded shape: {embeddings.shape}")
    return items, embeddings

def cluster_with_leiden(embeddings: np.ndarray, target_clusters: int = 30) -> np.ndarray:
    """Cluster embeddings using the Leiden algorithm."""
    print(f"Clustering {len(embeddings)} items into ~{target_clusters} clusters...")

    # Compute cosine similarity and build graph
    from sklearn.metrics.pairwise import cosine_similarity
    similarity = cosine_similarity(embeddings)

    # Build igraph (Leiden expects undirected graphs; use similarity as weights)
    n = len(embeddings)
    edges = []
    weights = []
    for i in range(n):
        for j in range(i + 1, n):
            if similarity[i, j] > 0.5:  # Only keep significant similarities
                edges.append((i, j))
                weights.append(similarity[i, j])

    g = Graph(n)
    g.add_edges(edges)
    g.es["weight"] = weights

    # Run Leiden algorithm with resolution tuning to target cluster count
    # Lower resolution = fewer clusters, higher = more clusters
    resolution = 0.5
    partition = la.find_partition(
        g,
        la.RBConfigurationVertexPartition,
        weights="weight",
        resolution_parameter=resolution,
        seed=42
    )

    labels = np.array(partition.membership)
    n_clusters = len(set(labels))
    print(f"  Found {n_clusters} clusters")

    return labels

def validate_balance(labels: np.ndarray, items: list[dict]) -> dict:
    """Validate cluster balance using std dev and other metrics."""
    cluster_sizes = np.bincount(labels)
    std_dev = np.std(cluster_sizes)
    mean_size = np.mean(cluster_sizes)

    balance_metrics = {
        "n_clusters": len(cluster_sizes),
        "mean_cluster_size": float(mean_size),
        "std_dev": float(std_dev),
        "min_cluster_size": int(np.min(cluster_sizes)),
        "max_cluster_size": int(np.max(cluster_sizes)),
        "imbalance_ratio": float(np.max(cluster_sizes) / np.min(cluster_sizes)),
    }

    print(f"\nCluster Balance Metrics:")
    print(f"  Clusters: {balance_metrics['n_clusters']}")
    print(f"  Mean size: {balance_metrics['mean_cluster_size']:.1f}")
    print(f"  Std dev: {balance_metrics['std_dev']:.2f}")
    print(f"  Range: {balance_metrics['min_cluster_size']}–{balance_metrics['max_cluster_size']}")
    print(f"  Imbalance ratio: {balance_metrics['imbalance_ratio']:.2f}")

    return balance_metrics

def save_results(items: list[dict], labels: np.ndarray, metrics: dict, output_file: str):
    """Save clustering results to a JSON file."""
    results = {
        "metadata": metrics,
        "clusters": {}
    }

    # Group items by cluster
    for cluster_id in range(metrics["n_clusters"]):
        mask = labels == cluster_id
        cluster_items = [
            {
                "id": items[i]["id"],
                "title": items[i]["title"],
                "kind": items[i]["kind"],
                "creator": items[i].get("primary_creator")
            }
            for i in np.where(mask)[0]
        ]
        results["clusters"][str(cluster_id)] = cluster_items

    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\nResults saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Cluster media items into semantic genres")
    parser.add_argument("--test", action="store_true", help="Run on a small test set (100 items)")
    parser.add_argument("--full", action="store_true", help="Run on the full catalog")
    parser.add_argument("--validate", action="store_true", help="Validate a clustering result")
    args = parser.parse_args()

    if args.test:
        items, embeddings = embed_items(*fetch_media(limit=100))
        output = "test_clustering_result.json"
    elif args.full:
        items, embeddings = embed_items(*fetch_media())
        output = "full_clustering_result.json"
    elif args.validate:
        print("Validation mode not yet implemented")
        return
    else:
        parser.print_help()
        return

    labels = cluster_with_leiden(embeddings, target_clusters=30)
    metrics = validate_balance(labels, items)
    save_results(items, labels, metrics, output)

if __name__ == "__main__":
    main()
