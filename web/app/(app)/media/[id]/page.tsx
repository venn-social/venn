import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { DetailUnavailable } from "@/components/DetailUnavailable";
import { MediaCover } from "@/components/MediaCover";
import { StarIcon } from "@/components/Icon";
import { ComposerLauncher } from "@/components/ComposerLauncher";
import { WatchLinks } from "@/components/WatchLinks";
import { regionFrom } from "@/lib/catalog/detail";
import { candidateFromMedia } from "@/lib/catalog/types";
import { fetchMediaById, formatRuntime, loadMediaDetail } from "@/lib/mediaDetail";
import { mediaMetadata } from "@/lib/media";
import { createClient } from "@/lib/supabase/server";

interface MediaPageProps {
  params: Promise<{ id: string }>;
}

/**
 * Everything worth knowing about one title. Reached by tapping a title
 * anywhere — the feed, a profile shelf, Explorer, or a list.
 *
 * The page renders from our own `media` row first and layers provider
 * detail on top, so it stays useful even when the provider is unreachable.
 */
export default async function MediaPage({ params }: MediaPageProps) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const media = await fetchMediaById(supabase, id);
  if (!media) {
    notFound();
  }

  // The provider is called in-process rather than over HTTP to our own
  // API. Building an outbound URL from the request's Host header and
  // forwarding the session cookie to it would let a spoofed Host ship that
  // cookie to an attacker; there's no reason for a Server Component to
  // round-trip through its own origin at all.
  const detail = await loadMediaDetail(media, regionFrom(await headers()));

  const metadata = mediaMetadata(media);
  const runtime = formatRuntime(detail.runtime);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg lg:max-w-2xl flex-col gap-6 px-4 py-8">
      <div className="flex gap-4">
        <div className="w-[120px] shrink-0">
          <MediaCover media={media} />
        </div>

        <div className="flex flex-col gap-1">
          <h1 className="text-xl font-semibold text-(--color-text-primary)">{media.title}</h1>
          {metadata && <p className="text-(--color-text-secondary)">{metadata}</p>}

          <div className="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-sm text-(--color-text-secondary)">
            {runtime && <span>{runtime}</span>}
            {detail.pageCount && <span>{detail.pageCount} pages</span>}
            {detail.rating !== null && (
              <span className="flex items-center gap-1">
                <StarIcon size={14} className="text-(--color-accent)" /> {detail.rating.toFixed(1)}
              </span>
            )}
          </div>

          <ComposerLauncher
            userId={user.id}
            initialPicked={candidateFromMedia(media)}
            className="mt-2 self-start rounded-pill bg-(--color-accent) px-4 py-1.5 text-sm font-semibold text-(--color-on-accent)"
          >
            Log this
          </ComposerLauncher>
        </div>
      </div>

      {detail.unavailable && <DetailUnavailable />}

      {detail.overview && (
        <section className="flex flex-col gap-2">
          <h2 className="font-semibold text-(--color-text-primary)">About</h2>
          <p className="text-(--color-text-primary)">{detail.overview}</p>
        </section>
      )}

      <WatchLinks links={detail.watchLinks} region={detail.watchRegion} kind={media.kind} />

      {detail.creators.length > 0 && (
        <section className="flex flex-col gap-2">
          <h2 className="font-semibold text-(--color-text-primary)">
            {detail.creators[0].role === "Author"
              ? "Author"
              : detail.creators[0].role === "Artist"
                ? "Artist"
                : "Directed by"}
          </h2>
          <p className="text-(--color-text-primary)">
            {detail.creators.map((person) => person.name).join(", ")}
          </p>
        </section>
      )}

      {detail.credits.length > 0 && (
        <section className="flex flex-col gap-2">
          <h2 className="font-semibold text-(--color-text-primary)">Cast</h2>
          <ul className="flex flex-col gap-1">
            {detail.credits.map((person) => (
              <li key={`${person.name}-${person.role ?? ""}`} className="text-sm">
                <span className="text-(--color-text-primary)">{person.name}</span>
                {person.role && (
                  <span className="text-(--color-text-secondary)"> as {person.role}</span>
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      {detail.genres.length > 0 && (
        <section className="flex flex-col gap-2">
          <h2 className="font-semibold text-(--color-text-primary)">Genres</h2>
          <div className="flex flex-wrap gap-2">
            {detail.genres.map((genre) => (
              <span
                key={genre}
                className="rounded-pill bg-(--color-surface-strong) px-3 py-1 text-sm text-(--color-text-secondary)"
              >
                {genre}
              </span>
            ))}
          </div>
        </section>
      )}

      {detail.sourceUrl && (
        <a
          href={detail.sourceUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm font-semibold text-(--color-accent)"
        >
          More on {sourceLabel(media.externalSource)} ↗
        </a>
      )}
    </main>
  );
}

function sourceLabel(source: string | null): string {
  switch (source) {
    case "tmdb":
      return "TMDB";
    case "openlibrary":
      return "OpenLibrary";
    case "musicbrainz":
      return "MusicBrainz";
    default:
      return "the source";
  }
}
