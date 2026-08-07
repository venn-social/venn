import Foundation
import Supabase

/// Which tier a shelf came from. Ordered by how much venn knows about you.
enum ShelfSource: String, Codable, Sendable {
    case tasteTwins = "taste_twins"
    case followed
    case similar
    case trending
}

/// Something the viewer loved, used to ask a catalog for more like it.
struct RecommendationSeed: Equatable, Sendable, Decodable {
    let mediaID: UUID
    let title: String
    let kind: MediaKind
    let externalSource: ExternalSource
    let externalID: String
    let rating: Double

    enum CodingKeys: String, CodingKey {
        case title, kind, rating
        case mediaID = "media_id"
        case externalSource = "external_source"
        case externalID = "external_id"
    }
}

/// A catalog item the viewer has already dealt with.
struct ExcludedKey: Hashable, Sendable, Decodable {
    let source: ExternalSource
    let kind: MediaKind
    let id: String

    /// `"<source>:<kind>:<id>"` — byte-identical to web's `candidateId()`
    /// and to `MediaCandidate.id`. Kind is load-bearing: TMDB numbers
    /// movies and TV independently, so movie 123 and show 123 are
    /// different things that would otherwise collide.
    var key: String {
        "\(source.rawValue):\(kind.rawValue):\(id)"
    }
}

/// One tier that came straight from venn's own data.
struct FeedSection: Equatable, Sendable {
    let source: ShelfSource
    let items: [Media]
}

/// Exactly what `recommendation_feed()` returns.
struct RecommendationFeed: Equatable, Sendable, Decodable {
    let sections: [FeedSection]
    let seeds: [RecommendationSeed]
    let excluded: [ExcludedKey]

    static let empty = RecommendationFeed(sections: [], seeds: [], excluded: [])

    init(sections: [FeedSection], seeds: [RecommendationSeed], excluded: [ExcludedKey]) {
        self.sections = sections
        self.seeds = seeds
        self.excluded = excluded
    }

    private struct RawSection: Decodable {
        let source: String
        let items: [MediaSchema.Row]
    }

    private enum CodingKeys: String, CodingKey {
        case sections, seeds, excluded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seeds = try container.decodeIfPresent([RecommendationSeed].self, forKey: .seeds) ?? []
        excluded = try container.decodeIfPresent([ExcludedKey].self, forKey: .excluded) ?? []

        // A tier added server-side ahead of a client release is dropped
        // rather than crashing an older app.
        let raw = try container.decodeIfPresent([RawSection].self, forKey: .sections) ?? []
        sections = raw.compactMap { section in
            guard let source = ShelfSource(rawValue: section.source) else { return nil }
            return FeedSection(source: source, items: section.items.compactMap(Media.init(row:)))
        }
    }
}

/// Behind a protocol so the view-model unit-tests with a fake (ADR 0005).
protocol RecommendationServicing: Sendable {
    func feed() async throws -> RecommendationFeed
}

/// Production implementation. Funnels errors through `AppError.from(_:)`
/// so callers see one semantic error type (ADR 0006).
struct RecommendationService: RecommendationServicing {
    let client: SupabaseClient

    func feed() async throws -> RecommendationFeed {
        do {
            return try await client
                .rpc("recommendation_feed")
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }
}
