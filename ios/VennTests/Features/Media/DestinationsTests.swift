import Foundation
import Testing
@testable import Venn

/// The rule table that replaced catalog links with links to the service.
///
/// The templates themselves were checked against the live sites by hand;
/// these cover the part that can rot silently — matching a provider name to
/// a rule, and building a URL that survives odd titles. Mirrors web's
/// `web/lib/catalog/destinations.test.ts` case for case (rule 17).
struct DestinationsTests {
    private func url(_ provider: String, _ title: String, _ region: String?) -> String? {
        Destinations.providerURL(provider: provider, title: title, region: region)?.absoluteString
    }

    // MARK: - providerURL

    @Test("sends each provider to its own site, not to a catalog")
    func ownSite() {
        #expect(url("Netflix", "Her", "GB") == "https://www.netflix.com/search?q=Her")
        #expect(url("Hulu", "Her", "US") == "https://www.hulu.com/search?q=Her")
        #expect(url("Disney Plus", "Her", "GB") == "https://www.disneyplus.com/browse/search?q=Her")
    }

    @Test("treats TMDB's ad and quality tiers as the same website")
    func tiersCollapse() {
        // TMDB lists these as separate providers. They are one site, and a
        // viewer who sees "Netflix Standard with Ads" still just wants
        // Netflix.
        for tier in ["Netflix", "Netflix Standard with Ads", "Netflix basic with Ads"] {
            #expect(url(tier, "Her", "GB") == "https://www.netflix.com/search?q=Her")
        }
    }

    @Test("prefers the more specific rule when one name contains another")
    func ordering() {
        // "youtube" is a prefix of "youtubepremium", and Amazon has three
        // spellings across TMDB's data. Ordering is what keeps these apart.
        #expect(url("Amazon Prime Video", "Her", "GB")?.contains("i=instant-video") == true)
        #expect(url("Amazon Video", "Her", "GB")?.contains("i=instant-video") == true)
        #expect(url("YouTube Premium", "Her", "GB")?.contains("youtube.com/results") == true)
    }

    @Test("uses the viewer's Amazon storefront, so prices are in their currency")
    func storefront() {
        #expect(url("Amazon Video", "Her", "GB")?.contains("amazon.co.uk") == true)
        #expect(url("Amazon Video", "Her", "FR")?.contains("amazon.fr") == true)
        #expect(url("Amazon Video", "Her", "JP")?.contains("amazon.co.jp") == true)
    }

    @Test("returns nil for a provider we have no verified URL for")
    func unknownProvider() {
        // An unlinked chip is honest. A guessed URL that 404s is worse than
        // the catalog link this feature replaced.
        #expect(url("Rakuten TV", "Her", "GB") == nil)
        #expect(url("Some New Service", "Her", "GB") == nil)
    }

    @Test("escapes titles that would otherwise break the query")
    func escaping() {
        #expect(
            url("Netflix", "Fast & Furious: Tokyo Drift", "GB")
                == "https://www.netflix.com/search?q=Fast%20%26%20Furious%3A%20Tokyo%20Drift"
        )
    }

    // MARK: - withProviderURLs

    @Test("keeps TMDB's link for providers it can't reach directly")
    func tmdbFallback() {
        let tmdb = URL(string: "https://www.themoviedb.org/movie/152601-her/watch?locale=GB")
        let enriched = Destinations.withProviderURLs(
            [
                WatchLink(provider: "Netflix", kind: .stream, url: tmdb, logoURL: nil),
                WatchLink(provider: "Rakuten TV", kind: .rent, url: tmdb, logoURL: nil),
            ],
            title: "Her",
            region: "GB"
        )

        #expect(enriched[0].url?.absoluteString == "https://www.netflix.com/search?q=Her")
        #expect(enriched[1].url == tmdb)
    }

    @Test("leaves everything else about the entry alone")
    func preservesFields() {
        let logo = URL(string: "https://image.tmdb.org/logo.png")
        let enriched = Destinations.withProviderURLs(
            [WatchLink(provider: "Netflix", kind: .rent, url: nil, logoURL: logo)],
            title: "Her",
            region: "GB"
        )

        #expect(enriched[0].kind == .rent)
        #expect(enriched[0].logoURL == logo)
    }

    // MARK: - readOrListenLinks

    @Test("offers shops for a book and services for an album")
    func perKindDestinations() {
        let books = Destinations.readOrListenLinks(
            kind: .book, title: "Kafka on the Shore", creator: "Haruki Murakami", region: "GB"
        )
        #expect(books.map(\.provider) == ["Kindle", "Amazon", "Apple Books", "Google Books"])

        let albums = Destinations.readOrListenLinks(
            kind: .album, title: "Kid A", creator: "Radiohead", region: "GB"
        )
        #expect(albums.map(\.provider) == ["Spotify", "Apple Music", "YouTube Music", "Bandcamp"])
    }

    @Test("includes the creator, because titles collide")
    func creatorInQuery() {
        // "Kid A" alone is ambiguous on every music service.
        let links = Destinations.readOrListenLinks(
            kind: .album, title: "Kid A", creator: "Radiohead", region: "GB"
        )
        #expect(links[0].url?.absoluteString == "https://open.spotify.com/search/Kid%20A%20Radiohead")
    }

    @Test("works with no creator known")
    func noCreator() {
        let links = Destinations.readOrListenLinks(
            kind: .album, title: "Kid A", creator: nil, region: "GB"
        )
        #expect(links[0].url?.absoluteString == "https://open.spotify.com/search/Kid%20A")
    }

    @Test("points Kindle at the digital store and Amazon at print")
    func kindleVersusPrint() {
        let links = Destinations.readOrListenLinks(
            kind: .book, title: "Dune", creator: "Frank Herbert", region: "US"
        )
        #expect(links[0].url?.absoluteString.contains("i=digital-text") == true)
        #expect(links[1].url?.absoluteString.contains("i=stripbooks") == true)
        #expect(links[0].kind == .buy)
    }

    @Test("uses the regional Apple storefront and falls back to US")
    func appleStorefront() {
        let french = Destinations.readOrListenLinks(
            kind: .book, title: "Dune", creator: nil, region: "FR"
        )
        #expect(french[2].url?.absoluteString.contains("books.apple.com/fr/") == true)

        // An unknown region must not produce books.apple.com//search.
        let unknown = Destinations.readOrListenLinks(
            kind: .book, title: "Dune", creator: nil, region: nil
        )
        #expect(unknown[2].url?.absoluteString.contains("books.apple.com/us/") == true)
    }

    @Test("has nothing to offer for screen media, which TMDB covers instead")
    func screenExcluded() {
        #expect(Destinations.readOrListenLinks(
            kind: .movie, title: "Her", creator: nil, region: "GB"
        ).isEmpty)
        #expect(Destinations.readOrListenLinks(
            kind: .show, title: "Severance", creator: nil, region: "GB"
        ).isEmpty)
    }

    @Test("offers nothing rather than an empty search when there's no title")
    func blankTitle() {
        #expect(Destinations.readOrListenLinks(
            kind: .book, title: "   ", creator: "Someone", region: "GB"
        ).isEmpty)
    }

    // MARK: - amazonDomain

    @Test("falls back to .com for regions with no storefront of their own")
    func amazonFallback() {
        #expect(Destinations.amazonDomain("GB") == "co.uk")
        #expect(Destinations.amazonDomain("gb") == "co.uk")
        #expect(Destinations.amazonDomain("NO") == "com")
        #expect(Destinations.amazonDomain(nil) == "com")
    }

    // MARK: - Labels

    @Test("a bare link reads as Find on a book and Watch on a film")
    func kindLabels() {
        #expect(WatchLink.Kind.link.label(for: .book) == "Find")
        #expect(WatchLink.Kind.link.label(for: .album) == "Find")
        #expect(WatchLink.Kind.link.label(for: .movie) == "Watch")
        #expect(WatchLink.Kind.stream.label(for: .book) == "Stream")
    }
}
