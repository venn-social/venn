import Foundation

/// Links that go to the service, not to a catalog page. Mirrors web's
/// `lib/catalog/destinations.ts` case for case (CLAUDE.md rule 17).
///
/// The three catalogs we read all stop short of this. TMDB names the
/// providers ("Netflix", "Amazon Video") and says whether it's stream, rent
/// or buy, but ships exactly one URL per *region* pointing back at
/// themoviedb.org — there is no per-provider link in the response. Open
/// Library and MusicBrainz carry no purchase or streaming links at all. So
/// "open this on Netflix" is something venn has to construct or not offer.
///
/// It is a rule table rather than data stored per item: one entry per
/// provider, applied to every title by filling in its name. Nothing here is
/// specific to a particular film or book, so a title logged tomorrow gets
/// the same treatment as one logged today, with no backfill.
///
/// These land on the provider's *search* results for the title, not on the
/// title's own page. Deep links need each service's internal id, which none
/// of them publish. A search on Netflix for the exact title is one tap from
/// playing; the TMDB page it replaces was not.
///
/// Every template was checked against the live site before it was added.
/// Providers whose search URL could not be confirmed are deliberately
/// absent — an unlinked chip is honest, a 404 is not.
enum Destinations {
    /// Amazon runs a separate storefront per country, and a link to the
    /// wrong one shows prices in the wrong currency. Regions we don't know
    /// fall back to .com rather than guessing a suffix that may not exist.
    private static let amazonDomains: [String: String] = [
        "AU": "com.au", "BE": "com.be", "BR": "com.br", "CA": "ca",
        "DE": "de", "ES": "es", "FR": "fr", "GB": "co.uk",
        "IE": "co.uk", "IN": "in", "IT": "it", "JP": "co.jp",
        "MX": "com.mx", "NL": "nl", "PL": "pl", "SE": "se",
        "SG": "sg", "TR": "com.tr", "US": "com",
    ]

    static func amazonDomain(_ region: String?) -> String {
        amazonDomains[(region ?? "").uppercased()] ?? "com"
    }

    /// Apple's stores are addressed by a lowercase country segment. An
    /// unknown one 404s, so anything unrecognised goes to the US store,
    /// which is where Apple itself falls back to.
    private static func appleStorefront(_ region: String?) -> String {
        let code = (region ?? "").lowercased()
        let isTwoLetters = code.count == 2 && code.allSatisfy { $0.isLetter && $0.isASCII }
        return isTwoLetters ? code : "us"
    }

    /// Providers whose search URL is known good, matched against the name
    /// TMDB reports. Compared after normalisation, so "Netflix Standard
    /// with Ads" and "Netflix basic with Ads" both resolve to Netflix —
    /// TMDB lists ad-supported and 4K tiers separately and they are all the
    /// same website.
    ///
    /// Ordered: the first entry whose key the provider name starts with
    /// wins, so longer keys come first ("amazonprimevideo" before "amazon").
    private static let screenProviders: [(key: String, url: @Sendable (String, String) -> String)] = [
        ("netflix", { query, _ in "https://www.netflix.com/search?q=\(query)" }),
        ("disneyplus", { query, _ in "https://www.disneyplus.com/browse/search?q=\(query)" }),
        ("appletv", { query, _ in "https://tv.apple.com/search?term=\(query)" }),
        ("itunes", { query, _ in "https://tv.apple.com/search?term=\(query)" }),
        ("amazonprimevideo", { query, region in amazonVideo(query, region) }),
        ("amazonvideo", { query, region in amazonVideo(query, region) }),
        ("primevideo", { query, region in amazonVideo(query, region) }),
        ("googleplaymovies", { query, _ in
            "https://play.google.com/store/search?q=\(query)&c=movies"
        }),
        ("youtubepremium", { query, _ in youTube(query) }),
        ("youtube", { query, _ in youTube(query) }),
        ("hulu", { query, _ in "https://www.hulu.com/search?q=\(query)" }),
        ("max", { query, _ in "https://play.max.com/search?q=\(query)" }),
        ("hbomax", { query, _ in "https://play.max.com/search?q=\(query)" }),
        ("paramountplus", { query, _ in "https://www.paramountplus.com/search/?q=\(query)" }),
        ("bbciplayer", { query, _ in "https://www.bbc.co.uk/iplayer/search?q=\(query)" }),
        ("mubi", { query, region in
            "https://mubi.com/en/\(region.isEmpty ? "us" : region.lowercased())/search/\(query)"
        }),
    ]

    private static func amazonVideo(_ query: String, _ region: String) -> String {
        "https://www.amazon.\(amazonDomain(region))/s?k=\(query)&i=instant-video"
    }

    private static func youTube(_ query: String) -> String {
        "https://www.youtube.com/results?search_query=\(query)"
    }

    /// One place to read or listen, before the query is filled in.
    private struct Destination: Sendable {
        let provider: String
        let kind: WatchLink.Kind
        let url: @Sendable (String, String) -> String
    }

    /// Where to read a book. Same list for everyone; the storefront is
    /// regional.
    private static let bookDestinations: [Destination] = [
        Destination(provider: "Kindle", kind: .buy) { query, region in
            "https://www.amazon.\(amazonDomain(region))/s?k=\(query)&i=digital-text"
        },
        Destination(provider: "Amazon", kind: .buy) { query, region in
            "https://www.amazon.\(amazonDomain(region))/s?k=\(query)&i=stripbooks"
        },
        Destination(provider: "Apple Books", kind: .buy) { query, region in
            "https://books.apple.com/\(appleStorefront(region))/search?term=\(query)"
        },
        Destination(provider: "Google Books", kind: .link) { query, _ in
            "https://www.google.com/search?q=\(query)&tbm=bks"
        },
    ]

    /// Where to listen to an album.
    private static let albumDestinations: [Destination] = [
        // Album-scoped: the bare /search/<q> lands on everything at once —
        // songs, artists, playlists, podcasts — and the album is rarely the
        // first thing you see.
        Destination(provider: "Spotify", kind: .stream) { query, _ in
            "https://open.spotify.com/search/\(query)/albums"
        },
        Destination(provider: "Apple Music", kind: .stream) { query, region in
            "https://music.apple.com/\(appleStorefront(region))/search?term=\(query)"
        },
        Destination(provider: "YouTube Music", kind: .stream) { query, _ in
            "https://music.youtube.com/search?q=\(query)"
        },
    ]

    /// Lowercased letters and digits only, so spelling and tier drop out.
    private static func normalise(_ provider: String) -> String {
        provider.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// Percent-encoding that matches JavaScript's `encodeURIComponent`, so
    /// both platforms produce byte-identical URLs. `.urlQueryAllowed` alone
    /// leaves `&`, `+` and `=` intact, which would corrupt the query.
    private static func encode(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            + "abcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }

    /// The provider's own search page for this title, or nil when we don't
    /// know the provider. Nil keeps the chip unlinked rather than sending
    /// someone somewhere wrong.
    static func providerURL(provider: String, title: String, region: String?) -> URL? {
        let name = normalise(provider)
        guard let match = screenProviders.first(where: { name.hasPrefix($0.key) }) else {
            return nil
        }
        return URL(string: match.url(encode(title), (region ?? "").uppercased()))
    }

    /// TMDB's availability, pointed at the providers themselves.
    ///
    /// Keeps TMDB's region link as the fallback for providers we can't
    /// reach directly: it still answers "where do I watch this", just with
    /// a stop on the way.
    static func withProviderURLs(
        _ links: [WatchLink],
        title: String,
        region: String?
    ) -> [WatchLink] {
        links.map { link in
            WatchLink(
                provider: link.provider,
                kind: link.kind,
                url: providerURL(provider: link.provider, title: title, region: region) ?? link.url,
                logoURL: link.logoURL
            )
        }
    }

    /// Where to read or listen to something, built from the title and
    /// creator alone.
    ///
    /// Books and albums have no availability data anywhere we look, so
    /// unlike the screen list this is not a claim that the item is stocked
    /// — it is a search we can run for you. The view says so.
    ///
    /// The creator is part of the query because titles collide badly: "Kid
    /// A" alone is ambiguous on every music service, "Kid A Radiohead" is
    /// not.
    static func readOrListenLinks(
        kind: MediaKind,
        title: String,
        creator: String?,
        region: String?
    ) -> [WatchLink] {
        let destinations: [Destination] = switch kind {
        case .book: bookDestinations
        case .album: albumDestinations
        default: []
        }
        guard !destinations.isEmpty,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return [] }

        let terms = [title, creator].compactMap(\.self).joined(separator: " ")
        let query = encode(terms.trimmingCharacters(in: .whitespacesAndNewlines))
        let upper = (region ?? "").uppercased()

        return destinations.map { destination in
            WatchLink(
                provider: destination.provider,
                kind: destination.kind,
                url: URL(string: destination.url(query, upper)),
                logoURL: nil
            )
        }
    }
}
