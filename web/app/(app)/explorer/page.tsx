import { redirect } from "next/navigation";
import { Explorer } from "@/components/Explorer";
import { fetchSimilar, fetchTrending } from "@/lib/catalog/similar";
import { assembleShelves, type RecommendationFeed, type Shelf } from "@/lib/recommendations";
import { createClient } from "@/lib/supabase/server";

export default async function ExplorerPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const shelves = await loadShelves(supabase);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 pt-5 pb-8">
      <Explorer shelves={shelves} />
    </main>
  );
}

/**
 * Recommendations are decoration relative to search: if any of this fails,
 * Explorer still works. Every branch degrades to fewer shelves rather than
 * to an error, and `allSettled` means one catalog being down costs one
 * shelf rather than all of them.
 */
async function loadShelves(supabase: Awaited<ReturnType<typeof createClient>>): Promise<Shelf[]> {
  try {
    const { data, error } = await supabase.rpc("recommendation_feed");
    if (error) return [];

    const feed = (data ?? { sections: [], seeds: [], excluded: [] }) as RecommendationFeed;
    const apiKey = process.env.TMDB_API_KEY;

    const settled = await Promise.allSettled([
      ...feed.seeds.map((seed) => fetchSimilar(seed, apiKey)),
      fetchTrending(apiKey)
    ]);

    const candidateShelves = settled.map((result, index) => ({
      source: (index < feed.seeds.length ? "similar" : "trending") as "similar" | "trending",
      seedTitle: index < feed.seeds.length ? feed.seeds[index].title : null,
      candidates: result.status === "fulfilled" ? result.value : []
    }));

    return assembleShelves(feed, candidateShelves);
  } catch {
    return [];
  }
}
