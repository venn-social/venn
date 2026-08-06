import Foundation
import Testing
@testable import Venn

/// Tests for TMDBService wire-format decoding and MediaCandidate mapping.
/// No network calls — we feed raw JSON into the decoders directly and
/// verify the mapping logic, same pattern as FeedServiceTests.
struct TMDBServiceTests {
    // MARK: - Movie decoding + mapping

    @Test
    func decodesMovieAndMapsToCandidate() throws {
        let json = Data("""
        {
          "id": 238,
          "title": "The Godfather",
          "release_date": "1972-03-24",
          "poster_path": "/3bhkrj58Vtu7enYsLegHnDmni2O.jpg"
        }
        """.utf8)

        let movie = try JSONDecoder().decode(TMDBMovie.self, from: json)
        let candidate = TMDBService.candidate(from: movie)

        #expect(candidate.title == "The Godfather")
        #expect(candidate.year == 1972)
        #expect(candidate.externalID == "238")
        #expect(candidate.externalSource == .tmdb)
        #expect(candidate.kind == .movie)
        #expect(candidate.coverURL?.absoluteString.hasSuffix("3bhkrj58Vtu7enYsLegHnDmni2O.jpg") == true)
    }

    @Test
    func movieWithNoPosterProducesNilCoverURL() throws {
        let json = Data("""
        { "id": 1, "title": "No Poster", "release_date": "2024-01-01", "poster_path": null }
        """.utf8)
        let movie = try JSONDecoder().decode(TMDBMovie.self, from: json)
        #expect(TMDBService.candidate(from: movie).coverURL == nil)
    }

    @Test
    func movieWithEmptyReleaseDateProducesNilYear() {
        let movie = TMDBMovie(id: 1, title: "Unreleased", releaseDate: "", posterPath: nil, overview: nil)
        #expect(TMDBService.candidate(from: movie).year == nil)
    }

    @Test
    func movieWithNilReleaseDateProducesNilYear() {
        let movie = TMDBMovie(id: 1, title: "TBA", releaseDate: nil, posterPath: nil, overview: nil)
        #expect(TMDBService.candidate(from: movie).year == nil)
    }

    // MARK: - Show decoding + mapping

    @Test
    func decodesShowAndMapsToCandidate() throws {
        let json = Data("""
        {
          "id": 1399,
          "name": "Game of Thrones",
          "first_air_date": "2011-04-17",
          "poster_path": "/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg"
        }
        """.utf8)

        let show = try JSONDecoder().decode(TMDBShow.self, from: json)
        let candidate = TMDBService.candidate(from: show)

        #expect(candidate.title == "Game of Thrones")
        #expect(candidate.year == 2011)
        #expect(candidate.externalID == "1399")
        #expect(candidate.externalSource == .tmdb)
        #expect(candidate.kind == .show)
    }

    // MARK: - MediaCandidate id

    @Test
    func candidateIDIsStableAndUnique() {
        let movie = TMDBMovie(id: 550, title: "Fight Club", releaseDate: "1999-10-15", posterPath: nil, overview: nil)
        let candidate = TMDBService.candidate(from: movie)
        #expect(candidate.id == "tmdb:movie:550")
    }
}
