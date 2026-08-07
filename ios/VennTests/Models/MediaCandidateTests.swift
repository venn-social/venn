import Foundation
import Testing
@testable import Venn

struct MediaCandidateTests {
    private func candidate(kind: MediaKind, externalID: String) -> MediaCandidate {
        MediaCandidate(
            title: "Thing",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: externalID,
            externalSource: .tmdb,
            kind: kind
        )
    }

    @Test
    func kindIsPartOfTheIdentity() {
        // TMDB numbers movies and TV independently, so movie 123 and show
        // 123 are different things. Without kind in the key they collide —
        // visibly so in Explorer's "All" category, which searches both.
        #expect(candidate(kind: .movie, externalID: "123").id
            != candidate(kind: .show, externalID: "123").id)
    }

    @Test
    func matchesTheFormatWebUses() {
        // web/lib/catalog/types.ts candidateId() builds the same string.
        // Recommendations filter "already seen" by comparing these across
        // platforms, so the format is a contract, not an implementation
        // detail.
        #expect(candidate(kind: .movie, externalID: "666277").id == "tmdb:movie:666277")
    }
}
