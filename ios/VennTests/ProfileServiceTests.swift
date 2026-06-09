import Foundation
import Testing
@testable import Venn

/// Tests the pure shelf-lifting boundary — `distinctMedia(from:)` — that turns
/// joined media rows into de-duped domain models. The Supabase call itself
/// isn't mocked; this covers the logic that's easy to break.
struct ProfileServiceTests {
    @Test
    func dedupesByMediaIDPreservingOrder() {
        let shared = UUID()
        let other = UUID()
        let rows = [
            makeRow(id: shared, kind: "movie", title: "Past Lives"),
            makeRow(id: shared, kind: "movie", title: "Past Lives"),
            makeRow(id: other, kind: "book", title: "Normal People"),
        ]

        let media = ProfileService.distinctMedia(from: rows)

        #expect(media.map(\.id) == [shared, other])
        #expect(media.map(\.title) == ["Past Lives", "Normal People"])
    }

    @Test
    func dropsRowsWithUnknownKind() {
        let rows = [
            makeRow(id: UUID(), kind: "podcast", title: "Acquired"),
            makeRow(id: UUID(), kind: "album", title: "Blonde"),
        ]

        let media = ProfileService.distinctMedia(from: rows)

        #expect(media.map(\.title) == ["Blonde"])
    }

    @Test
    func emptyInEmptyOut() {
        #expect(ProfileService.distinctMedia(from: []).isEmpty)
    }

    private func makeRow(id: UUID, kind: String, title: String) -> MediaSchema.Row {
        MediaSchema.Row(
            id: id,
            kind: kind,
            title: title,
            year: nil,
            primaryCreator: nil,
            coverUrl: nil,
            externalId: nil,
            externalSource: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
