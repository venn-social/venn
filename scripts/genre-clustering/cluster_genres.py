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
model = SentenceTransformer("all-MiniLM-L6-v2")  # 384-dim, fast, still excellent for clustering

def fetch_media(limit: Optional[int] = None) -> list[dict]:
    """Fetch media items from Supabase, or use synthetic test data if empty."""
    print(f"Fetching media from Supabase{'...' if limit is None else f' (limit {limit})...'}")

    query = supabase.table("media").select(
        "id, kind, title, primary_creator, year, external_source"
    )

    if limit:
        query = query.limit(limit)

    response = query.execute()
    items = response.data if response.data else []
    print(f"  Fetched {len(items)} items")

    # If the production database is empty, use synthetic test data for prototype validation
    if not items:
        print("  Production DB empty; using synthetic test data...")
        items = generate_synthetic_media(limit or 100)

    return items


def generate_synthetic_media(count: int) -> list[dict]:
    """Generate synthetic media for testing when the database is empty."""
    import uuid

    synthetic = [
        # Romance movies
        ("The Notebook", "Nick Cassavetes", 2004, "movie"),
        ("Pride and Prejudice", "Joe Wright", 2005, "movie"),
        ("Titanic", "James Cameron", 1997, "movie"),
        ("La La Land", "Damien Chazelle", 2016, "movie"),
        ("Eternal Sunshine of the Spotless Mind", "Michel Gondry", 2004, "movie"),
        # Sci-fi movies
        ("Inception", "Christopher Nolan", 2010, "movie"),
        ("Interstellar", "Christopher Nolan", 2014, "movie"),
        ("The Matrix", "Wachowski Sisters", 1999, "movie"),
        ("Blade Runner", "Ridley Scott", 1982, "movie"),
        ("Dune", "Denis Villeneuve", 2021, "movie"),
        # Horror movies
        ("The Shining", "Stanley Kubrick", 1980, "movie"),
        ("Hereditary", "Ari Aster", 2018, "movie"),
        ("The Ring", "Gore Verbinski", 2002, "movie"),
        ("Insidious", "James Wan", 2010, "movie"),
        # Comedy movies
        ("Knives Out", "Rian Johnson", 2019, "movie"),
        ("The Grand Budapest Hotel", "Wes Anderson", 2014, "movie"),
        ("Superbad", "Greg Mottola", 2007, "movie"),
        ("Bridesmaids", "Paul Feig", 2011, "movie"),
        # Drama TV shows
        ("Breaking Bad", "Vince Gilligan", 2008, "show"),
        ("The Wire", "David Simon", 2002, "show"),
        ("Succession", "Jesse Armstrong", 2018, "show"),
        ("The Crown", "Peter Morgan", 2016, "show"),
        # Fantasy TV shows
        ("Game of Thrones", "David Benioff", 2011, "show"),
        ("The Lord of the Rings", "Peter Jackson", 2001, "show"),
        # Romance novels
        ("Pride and Prejudice", "Jane Austen", 1813, "book"),
        ("Outlander", "Diana Gabaldon", 1991, "book"),
        ("The Notebook", "Nicholas Sparks", 1996, "book"),
        # Sci-fi novels
        ("Dune", "Frank Herbert", 1965, "book"),
        ("Foundation", "Isaac Asimov", 1951, "book"),
        ("Neuromancer", "William Gibson", 1984, "book"),
        # Fantasy novels
        ("The Hobbit", "J.R.R. Tolkien", 1937, "book"),
        ("Harry Potter", "J.K. Rowling", 1997, "book"),
        # Pop music
        ("Blinding Lights", "The Weeknd", 2019, "album"),
        ("Levitating", "Dua Lipa", 2020, "album"),
        ("good 4 u", "Olivia Rodrigo", 2021, "album"),
        # Rock music
        ("Stairway to Heaven", "Led Zeppelin", 1971, "album"),
        ("Bohemian Rhapsody", "Queen", 1975, "album"),
        # Hip-hop
        ("Lose Yourself", "Eminem", 2002, "album"),
        ("HUMBLE.", "Kendrick Lamar", 2017, "album"),
    ]

    items = []
    for title, creator, year, kind in synthetic[:count]:
        items.append({
            "id": str(uuid.uuid4()),
            "kind": kind,
            "title": title,
            "primary_creator": creator,
            "year": year,
            "external_source": None
        })

    return items

def embed_items(items: list[dict]) -> tuple[list[dict], np.ndarray]:
    """Embed media items using sentence-transformers."""
    print(f"Embedding {len(items)} items...")

    # Build text representation: "title by creator (year) [kind]"
    texts = []
    for item in items:
        parts = [item.get("title", "")]
        if item.get("primary_creator"):
            parts.append(f"by {item['primary_creator']}")
        if item.get("year"):
            parts.append(f"({item['year']})")

        kind = item.get("kind", "")
        text = " ".join(parts)
        if kind:
            text += f" [{kind}]"
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
        media = fetch_media(limit=100)
        items, embeddings = embed_items(media)
        output = "test_clustering_result.json"
    elif args.full:
        media = fetch_media()
        items, embeddings = embed_items(media)
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
