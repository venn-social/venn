import type { WatchLink } from "@/lib/catalog/detail";
import type { MediaKind } from "@/lib/media";
import { regionName, watchKindLabel } from "@/lib/mediaDetail";

interface WatchLinksProps {
  links: WatchLink[];
  region: string | null;
  kind: MediaKind;
}

/**
 * Where you can watch this, for the region the request came from.
 *
 * The region is always stated. Streaming rights differ by country, so a
 * bare list of providers is a claim we can't support — "on Netflix" is
 * only true somewhere.
 */
export function WatchLinks({ links, region, kind }: WatchLinksProps) {
  // Only screen media has availability data; TMDB is the only provider
  // that carries it, so books and albums render nothing at all rather
  // than an empty section.
  if (kind !== "movie" && kind !== "show") return null;
  if (links.length === 0) return null;

  const where = regionName(region);

  return (
    <section className="flex flex-col gap-2">
      <h2 className="font-semibold text-(--color-text-primary)">
        Where to watch{where ? ` in ${where}` : ""}
      </h2>

      <ul className="flex flex-wrap gap-2">
        {links.map((link) => {
          const label = `${watchKindLabel(link.kind)} on ${link.provider}`;
          const content = (
            <span className="flex items-center gap-2 rounded-pill border border-(--color-separator) px-3 py-1.5 text-sm">
              {link.logoUrl && (
                // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
                <img
                  src={link.logoUrl}
                  alt=""
                  width={20}
                  height={20}
                  loading="lazy"
                  className="rounded-sm"
                />
              )}
              <span className="text-(--color-text-primary)">{link.provider}</span>
              <span className="text-(--color-text-secondary)">{watchKindLabel(link.kind)}</span>
            </span>
          );

          return (
            <li key={`${link.provider}-${link.kind}`}>
              {link.url ? (
                <a href={link.url} target="_blank" rel="noopener noreferrer" aria-label={label}>
                  {content}
                </a>
              ) : (
                content
              )}
            </li>
          );
        })}
      </ul>

      <p className="text-xs text-(--color-text-secondary)">
        Availability from TMDB. Rights change often and vary by country.
      </p>
    </section>
  );
}
