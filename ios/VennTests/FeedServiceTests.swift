import Foundation
import Testing
@testable import Venn

/// Decoding + lifting tests for the FeedService wire layer. We don't mock
/// SupabaseClient; instead we verify the boundary that turns DB JSON into
/// `FeedPost` domain models. This is where forwards-compat (unknown enum
/// values) and field mapping are easiest to break.
struct FeedServiceTests {
    // MARK: - FeedPostRow JSON → domain

    @Test
    func feedPostRowDecodesAndLiftsToFeedPost() throws {
        let json = Self.makeRowJSON(
            action: "logged",
            mediaKind: "movie",
            mediaTitle: "Past Lives",
            authorUsername: "maya"
        )
        let row = try JSONDecoder.supabase.decode(FeedPostRow.self, from: json)
        let feed = try #require(FeedPost(row: row))

        #expect(feed.post.action == .logged)
        #expect(feed.media.kind == .movie)
        #expect(feed.media.title == "Past Lives")
        #expect(feed.author.username == "maya")
        #expect(feed.id == feed.post.id)
    }

    @Test
    func feedPostRowLiftsCoversRating() throws {
        let json = Self.makeRowJSON(action: "rated", rating: 4.5)
        let row = try JSONDecoder.supabase.decode(FeedPostRow.self, from: json)
        let feed = try #require(FeedPost(row: row))

        #expect(feed.post.action == .rated)
        #expect(feed.post.rating == 4.5)
    }

    // MARK: - forwards-compat

    @Test
    func unknownActionReturnsNil() throws {
        let json = Self.makeRowJSON(action: "celebrated")
        let row = try JSONDecoder.supabase.decode(FeedPostRow.self, from: json)
        #expect(FeedPost(row: row) == nil)
    }

    @Test
    func unknownMediaKindReturnsNil() throws {
        let json = Self.makeRowJSON(mediaKind: "podcast")
        let row = try JSONDecoder.supabase.decode(FeedPostRow.self, from: json)
        #expect(FeedPost(row: row) == nil)
    }

    // MARK: - Media + Post init?(row:)

    @Test
    func mediaInitFromKnownRow() throws {
        let row = MediaSchema.Row(
            id: UUID(),
            kind: "book",
            title: "The Hard Thing About Hard Things",
            year: 2014,
            primaryCreator: "Ben Horowitz",
            coverUrl: "https://example.com/cover.jpg",
            externalId: "OL12345W",
            externalSource: "openlibrary",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let media = try #require(Media(row: row))
        #expect(media.kind == .book)
        #expect(media.externalSource == .openlibrary)
        #expect(media.coverURL?.absoluteString == "https://example.com/cover.jpg")
    }

    @Test
    func mediaInitNilsOnUnknownKind() {
        let row = MediaSchema.Row(
            id: UUID(),
            kind: "podcast",
            title: "Acquired",
            year: nil,
            primaryCreator: nil,
            coverUrl: nil,
            externalId: nil,
            externalSource: nil,
            createdAt: Date()
        )
        #expect(Media(row: row) == nil)
    }

    // MARK: - helpers

    private static func makeRowJSON(
        action: String = "logged",
        rating: Double? = nil,
        mediaKind: String = "movie",
        mediaTitle: String = "Past Lives",
        authorUsername: String = "maya"
    ) -> Data {
        let postID = UUID().uuidString.lowercased()
        let authorID = UUID().uuidString.lowercased()
        let mediaID = UUID().uuidString.lowercased()
        let ratingJSON = rating.map { "\($0)" } ?? "null"
        let json = """
        {
          "id": "\(postID)",
          "author_id": "\(authorID)",
          "media_id": "\(mediaID)",
          "action": "\(action)",
          "rating": \(ratingJSON),
          "caption": null,
          "created_at": "2026-05-15T20:00:00Z",
          "media": {
            "id": "\(mediaID)",
            "kind": "\(mediaKind)",
            "title": "\(mediaTitle)",
            "year": 2023,
            "primary_creator": "Celine Song",
            "cover_url": null,
            "external_id": null,
            "external_source": null,
            "metadata": {},
            "created_at": "2026-05-10T12:00:00Z"
          },
          "author": {
            "id": "\(authorID)",
            "username": "\(authorUsername)",
            "display_name": "Maya Chen",
            "avatar_url": null,
            "bio": null,
            "created_at": "2026-05-01T12:00:00Z"
          }
        }
        """
        return Data(json.utf8)
    }
}

private extension JSONDecoder {
    /// Matches the decoder Supabase Swift uses internally — ISO-8601 dates,
    /// no key strategy (we declare CodingKeys ourselves).
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
