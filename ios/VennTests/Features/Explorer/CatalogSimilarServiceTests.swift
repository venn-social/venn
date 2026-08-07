import Foundation
import Testing
@testable import Venn

/// Mapping only. Mirrors web's `similar.test.ts`.
struct CatalogSimilarServiceTests {
    @Test
    func keepsMoviesAndShowsAndLabelsEachCorrectly() throws {
        // /trending/all/week mixes both, distinguished by media_type.
        let json = Data(#"""
        {"results":[
          {"id":1,"media_type":"movie","title":"A Film","release_date":"2023-01-01"},
          {"id":2,"media_type":"tv","name":"A Show","first_air_date":"2022-01-01"}
        ]}
        """#.utf8)

        let candidates = try CatalogSimilarService.trendingCandidates(from: json)

        #expect(candidates.map(\.kind) == [.movie, .show])
        #expect(candidates[0].id == "tmdb:movie:1")
        #expect(candidates[1].id == "tmdb:show:2")
    }

    @Test
    func dropsPeopleWhichThatEndpointAlsoReturns() throws {
        // media_type "person" has no title and is not something you can log.
        let json = Data(#"""
        {"results":[
          {"id":3,"media_type":"person","name":"Someone"},
          {"id":4,"media_type":"movie","title":"A Film"}
        ]}
        """#.utf8)

        let candidates = try CatalogSimilarService.trendingCandidates(from: json)

        #expect(candidates.count == 1)
        #expect(candidates[0].kind == .movie)
    }

    @Test
    func survivesAPayloadWithNoResults() throws {
        #expect(try CatalogSimilarService.trendingCandidates(from: Data("{}".utf8)).isEmpty)
    }

    @Test
    func recommendationsTakeTheirKindFromTheCallerNotThePayload() throws {
        // The /recommendations payload carries no media_type, so the kind
        // comes from the seed. Without that every result would be dropped.
        let json = Data(#"""
        {"results":[{"id":7,"name":"A Show","first_air_date":"2019-05-19"}]}
        """#.utf8)

        let candidates = try CatalogSimilarService.tmdbCandidates(from: json, kind: .show)

        #expect(candidates.count == 1)
        #expect(candidates[0].id == "tmdb:show:7")
        #expect(candidates[0].year == 2019)
    }

    @Test
    func mapsTheSubjectsPayloadWhichIsNotTheSearchShape() throws {
        // /subjects/{name}.json returns `works` with `cover_id`, where
        // search returns `docs` with `cover_i`. The search mapper cannot
        // decode this, which is why there is a separate one.
        let json = Data(#"""
        {"works":[{
          "key":"/works/OL1W","title":"Piranesi",
          "authors":[{"name":"Susanna Clarke"}],
          "first_publish_year":2020,"cover_id":123
        }]}
        """#.utf8)

        let candidates = try CatalogSimilarService.bookCandidates(from: json)

        #expect(candidates.count == 1)
        // The "/works/" prefix is stripped so external_id matches what the
        // rest of the app stores.
        #expect(candidates[0].externalID == "OL1W")
        #expect(candidates[0].primaryCreator == "Susanna Clarke")
        #expect(candidates[0].year == 2020)
    }
}
