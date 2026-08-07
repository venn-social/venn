import Foundation
import Testing
@testable import Venn

/// Tests for OpenLibraryService wire-format decoding and MediaCandidate mapping.
struct OpenLibraryServiceTests {
    // MARK: - OLDoc decoding + mapping

    @Test
    func decodesDocAndMapsToCandidate() throws {
        let json = Data("""
        {
          "key": "/works/OL45804W",
          "title": "Hamlet",
          "author_name": ["William Shakespeare"],
          "first_publish_year": 1603,
          "cover_i": 12345
        }
        """.utf8)

        let doc = try JSONDecoder().decode(OLDoc.self, from: json)
        let candidate = OpenLibraryService.candidate(from: doc)

        #expect(candidate.title == "Hamlet")
        #expect(candidate.primaryCreator == "William Shakespeare")
        #expect(candidate.year == 1603)
        #expect(candidate.externalID == "OL45804W")
        #expect(candidate.externalSource == .openlibrary)
        #expect(candidate.kind == .book)
        #expect(candidate.coverURL?.absoluteString.contains("12345") == true)
    }

    @Test
    func docWithNoCoverProducesNilCoverURL() throws {
        let json = Data("""
        { "key": "/works/OL1W", "title": "No Cover", "author_name": null, "first_publish_year": null, "cover_i": null }
        """.utf8)
        let doc = try JSONDecoder().decode(OLDoc.self, from: json)
        #expect(OpenLibraryService.candidate(from: doc).coverURL == nil)
    }

    @Test
    func docWithNoAuthorsProducesNilCreator() throws {
        let json = Data("""
        { "key": "/works/OL2W", "title": "Anonymous Work", "author_name": [], "first_publish_year": 2000, "cover_i": null }
        """.utf8)
        let doc = try JSONDecoder().decode(OLDoc.self, from: json)
        #expect(OpenLibraryService.candidate(from: doc).primaryCreator == nil)
    }

    @Test
    func onlyFirstAuthorIsUsedAsPrimaryCreator() throws {
        let json = Data("""
        { "key": "/works/OL3W", "title": "Co-written", "author_name": ["Alice", "Bob"], "first_publish_year": 2010, "cover_i": null }
        """.utf8)
        let doc = try JSONDecoder().decode(OLDoc.self, from: json)
        #expect(OpenLibraryService.candidate(from: doc).primaryCreator == "Alice")
    }

    // MARK: - workKey helper

    @Test
    func workKeyStripsWorksPrefix() {
        #expect(OpenLibraryService.workKey(from: "/works/OL45804W") == "OL45804W")
    }

    @Test
    func workKeyPassesThroughBareKey() {
        #expect(OpenLibraryService.workKey(from: "OL45804W") == "OL45804W")
    }

    // MARK: - MediaCandidate id

    @Test
    func candidateIDIsStable() throws {
        let json = Data("""
        { "key": "/works/OL99W", "title": "Test", "author_name": null, "first_publish_year": null, "cover_i": null }
        """.utf8)
        let doc = try JSONDecoder().decode(OLDoc.self, from: json)
        // Kind is part of the identity — see MediaCandidate.id.
        #expect(OpenLibraryService.candidate(from: doc).id == "openlibrary:book:OL99W")
    }
}
