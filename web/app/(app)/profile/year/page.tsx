import { redirect } from "next/navigation";
import { YearActivityChart } from "@/components/YearActivityChart";
import { YearKindCard } from "@/components/YearKindCard";
import { createClient } from "@/lib/supabase/server";
import { fetchYearInReview, totalConsumed } from "@/lib/yearInReview";

export default async function YearInReviewPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let summary;
  try {
    summary = await fetchYearInReview(supabase);
  } catch (error) {
    const rateLimited = (error as { code?: string } | null)?.code === "P0429";
    return (
      <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Last 12 Months</h1>
        <p className="text-(--color-text-secondary)">
          {rateLimited ? "Too many requests — give it a moment." : "Couldn't load your stats."}
        </p>
      </main>
    );
  }

  const total = totalConsumed(summary.kinds);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-6 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Last 12 Months</h1>

      {total === 0 ? (
        <div className="flex flex-col gap-1 py-8 text-center">
          <p className="font-semibold text-(--color-text-primary)">Nothing logged yet</p>
          <p className="text-(--color-text-secondary)">
            Log a few things and your year in review builds up here.
          </p>
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-0.5">
            <p className="text-4xl font-semibold tabular-nums text-(--color-text-primary)">
              {total}
            </p>
            <p className="text-(--color-text-secondary)">logged in the last year</p>
          </div>

          {summary.monthly.length > 0 && <YearActivityChart monthly={summary.monthly} />}

          <div className="flex flex-col gap-2">
            {summary.kinds.map((stats) => (
              <YearKindCard key={stats.kind} stats={stats} />
            ))}
          </div>
        </>
      )}
    </main>
  );
}
