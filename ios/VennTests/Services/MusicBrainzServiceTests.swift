import Foundation
import Testing
@testable import Venn

/// Tests for MusicBrainzService wire-format decoding and MediaCandidate mapping.
struct MusicBrainzServiceTests {
    // MARK: - MBReleaseGroup decoding + mapping

    @Test
    func decodesReleaseGroupAndMapsToCandidate() throws {
        let json = Data("""
        {
          "id": "f5093c06-23e3-404f-aeaa-40f72885ee3a",
          "title": "OK Computer",
          "first-release-date": "1997-05-21",
          "artist-credit": [
            { "name": "Radiohead" }
          ]
        }
        """.utf8)

        let group = try JSONDecoder().decode(MBReleaseGroup.self, from: json)
        let candidate = MusicBrainzService.candidate(from: group)

        #expect(candidate.title == "OK Computer")
        #expect(candidate.primaryCreator == "Radiohead")
        #expect(candidate.year == 1997)
        #expect(candidate.externalID == "f5093c06-23e3-404f-aeaa-40f72885ee3a")
        #expect(candidate.externalSource == .musicbrainz)
        #expect(candidate.kind == .album)
    }

    @Test
    func candidateCoverPointsAtCoverArtArchiveFrontImage() throws {
        // Derived blind from the MBID — no lookup request. Missing art
        // 404s at render time and falls back to the tonal tile.
        let json = Data("""
        { "id": "f5093c06-23e3-404f-aeaa-40f72885ee3a", "title": "OK Computer",
          "first-release-date": "1997-05-21", "artist-credit": null }
        """.utf8)
        let group = try JSONDecoder().decode(MBReleaseGroup.self, from: json)

        let url = MusicBrainzService.candidate(from: group).coverURL

        #expect(url?.absoluteString ==
            "https://coverartarchive.org/release-group/f5093c06-23e3-404f-aeaa-40f72885ee3a/front-500")
    }

    @Test
    func releaseGroupWithNoArtistCreditProducesNilCreator() throws {
        let json = Data("""
        {
          "id": "abc123",
          "title": "No Artist",
          "first-release-date": "2000-01-01",
          "artist-credit": null
        }
        """.utf8)
        let group = try JSONDecoder().decode(MBReleaseGroup.self, from: json)
        #expect(MusicBrainzService.candidate(from: group).primaryCreator == nil)
    }

    @Test
    func releaseGroupWithEmptyArtistCreditProducesNilCreator() throws {
        let json = Data("""
        { "id": "abc124", "title": "VA", "first-release-date": "2001-01-01", "artist-credit": [] }
        """.utf8)
        let group = try JSONDecoder().decode(MBReleaseGroup.self, from: json)
        #expect(MusicBrainzService.candidate(from: group).primaryCreator == nil)
    }

    // MARK: - MediaCandidate id

    @Test
    func candidateIDIsStable() throws {
        let json = Data("""
        { "id": "test-uuid-001", "title": "T", "first-release-date": null, "artist-credit": null }
        """.utf8)
        let group = try JSONDecoder().decode(MBReleaseGroup.self, from: json)
        // Kind is part of the identity: TMDB numbers movies and TV
        // independently, so the key carries it on every provider for
        // consistency, and web builds the same string.
        #expect(MusicBrainzService.candidate(from: group).id == "musicbrainz:album:test-uuid-001")
    }
}
