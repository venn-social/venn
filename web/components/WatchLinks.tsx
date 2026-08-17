import type { WatchLink } from "@/lib/catalog/detail";
import type { MediaKind } from "@/lib/media";
import { regionName, watchKindLabel } from "@/lib/mediaDetail";

interface WatchLinksProps {
  links: WatchLink[];
  region: string | null;
  kind: MediaKind;
}

/**
 * Where you can actually watch, read, or listen to this.
 *
 * Screen availability comes from TMDB and is real: these providers carry
 * the title in this region. The region is always stated, because rights
 * differ by country and "on Netflix" is only true somewhere.
 *
 * Books and albums are a weaker claim and are labelled as one. No catalog
 * we read holds availability for them, so their links run a search on each
 * service rather than confirming it's stocked.
 */
export function WatchLinks({ links, region, kind }: WatchLinksProps) {
  if (links.length === 0) return null;

  const searchOnly = kind === "book" || kind === "album";
  const where = regionName(region);
  const heading = searchOnly
    ? `Where to ${kind === "book" ? "read" : "listen"}`
    : `Where to watch${where ? ` in ${where}` : ""}`;

  return (
    <section className="flex flex-col gap-2">
      <h2 className="font-semibold text-(--color-text-primary)">{heading}</h2>

      <ul className="flex flex-wrap gap-2">
        {links.map((link) => {
          const label = `${watchKindLabel(link.kind, kind)} on ${link.provider}`;
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
              <span className="text-(--color-text-secondary)">
                {watchKindLabel(link.kind, kind)}
              </span>
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
        {searchOnly
          ? "These search each service — we can't tell whether it's stocked."
          : "Availability from TMDB. Rights change often and vary by country."}
      </p>
    </section>
  );
}
