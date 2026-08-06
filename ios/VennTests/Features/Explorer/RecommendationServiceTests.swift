import Foundation
import Testing
@testable import Venn

/// Decoding the RPC payload, and the exclusion key's exact format — which
/// is a cross-platform contract, not an implementation detail.
struct RecommendationServiceTests {
    @Test
    func exclusionKeyMatchesTheFormatWebUses() {
        // web/lib/catalog/types.ts candidateId() builds the same string.
        let key = ExcludedKey(source: .tmdb, kind: .movie, id: "666277")
        #expect(key.key == "tmdb:movie:666277")
    }

    @Test
    func kindIsPartOfTheExclusionKey() {
        // Excluding the movie must not hide the show with the same number.
        let movie = ExcludedKey(source: .tmdb, kind: .movie, id: "5")
        let show = ExcludedKey(source: .tmdb, kind: .show, id: "5")
        #expect(movie.key != show.key)
    }

    @Test
    func decodesAnEmptyFeed() throws {
        // A brand-new user gets exactly this, and it is not an error.
        let json = Data(#"{"sections":[],"seeds":[],"excluded":[]}"#.utf8)
        let feed = try JSONDecoder().decode(RecommendationFeed.self, from: json)

        #expect(feed.sections.isEmpty)
        #expect(feed.seeds.isEmpty)
        #expect(feed.excluded.isEmpty)
    }

    @Test
    func decodesSeedsAndExclusions() throws {
        let json = Data(#"""
        {
          "sections": [],
          "seeds": [{
            "media_id": "22222222-2222-2222-2222-222222222222",
            "title": "Past Lives", "kind": "movie",
            "external_source": "tmdb", "external_id": "666277", "rating": 5.0
          }],
          "excluded": [{ "source": "tmdb", "kind": "movie", "id": "666277" }]
        }
        """#.utf8)
        let feed = try JSONDecoder().decode(RecommendationFeed.self, from: json)

        #expect(feed.seeds.first?.title == "Past Lives")
        #expect(feed.seeds.first?.externalSource == .tmdb)
        #expect(feed.excluded.first?.key == "tmdb:movie:666277")
    }

    @Test
    func dropsASectionWithAnUnknownSource() throws {
        // A future tier added server-side must not crash an older client.
        let json = Data(#"""
        {"sections":[{"source":"quantum","items":[]}],"seeds":[],"excluded":[]}
        """#.utf8)
        let feed = try JSONDecoder().decode(RecommendationFeed.self, from: json)

        #expect(feed.sections.isEmpty)
    }
}
