import Foundation

/// One thing on a shelf.
///
/// Rows from venn's own catalog can be opened directly; catalog results
/// have to be upserted into `public.media` first, so they open the
/// composer instead. The distinction is in the type rather than discovered
/// at render time.
enum ShelfItem: Identifiable, Equatable, Sendable {
    case media(Media)
    case candidate(MediaCandidate)

    /// `"<source>:<kind>:<externalId>"` where there is a catalog identity.
    /// Falls back to the row's UUID for a hand-typed entry, which can be
    /// neither excluded nor deduped — there is nothing to compare it to.
    var id: String {
        switch self {
        case let .candidate(candidate):
            candidate.id
        case let .media(media):
            if let source = media.externalSource, let externalID = media.externalID {
                "\(source.rawValue):\(media.kind.rawValue):\(externalID)"
            } else {
                media.id.uuidString
            }
        }
    }

    /// True when `id` is a cross-platform catalog key rather than a local
    /// UUID standing in for one.
    var hasCatalogIdentity: Bool {
        switch self {
        case .candidate: true
        case let .media(media): media.externalSource != nil && media.externalID != nil
        }
    }

    var title: String {
        switch self {
        case let .media(media): media.title
        case let .candidate(candidate): candidate.title
        }
    }

    /// The media kind, whichever case this is.
    var mediaKind: MediaKind {
        switch self {
        case let .media(media): media.kind
        case let .candidate(candidate): candidate.kind
        }
    }
}

/// A shelf, ready to render.
struct RecommendationShelf: Identifiable, Equatable, Sendable {
    let source: ShelfSource
    /// The title this shelf is "more like". Nil for every other tier.
    let seedTitle: String?
    let items: [ShelfItem]

    var id: String {
        "\(source.rawValue):\(seedTitle ?? "")"
    }

    /// Shelf heading.
    ///
    /// Mirrors web's `shelfTitle()` exactly (CLAUDE.md rule 17). Every
    /// label states what the shelf actually is — trending is not dressed
    /// up as a personal recommendation.
    var title: String {
        switch source {
        case .tasteTwins: "Popular with people who match your taste"
        case .followed: "Loved by people you follow"
        case .similar: seedTitle.map { "More like \($0)" } ?? "More like what you loved"
        case .trending: "Trending this week"
        }
    }
}

/// A shelf's worth of catalog results, before filtering.
struct CandidateShelf: Equatable, Sendable {
    let source: ShelfSource
    let seedTitle: String?
    let candidates: [MediaCandidate]
}

/// Turns the RPC payload and whatever the catalogs returned into the
/// shelves to render.
///
/// Pure by design: no network, no clock, no UI. This is the only logic
/// that exists on both platforms, so it is kept small enough to hold in
/// your head and tested with the same cases as web's `assembleShelves`
/// in web/lib/recommendations.ts.
enum RecommendationAssembler {
    /// Below this a shelf reads as broken rather than as a recommendation.
    static let minShelfItems = 3
    /// More than this and Explorer becomes a wall of rows.
    static let maxShelves = 4
    static let maxShelfItems = 12

    /// Tier order is fixed — see the spec's ladder.
    private static let tierOrder: [ShelfSource] = [.tasteTwins, .followed, .similar, .trending]

    static func assembleShelves(
        feed: RecommendationFeed,
        candidateShelves: [CandidateShelf]
    ) -> [RecommendationShelf] {
        let excluded = Set(feed.excluded.map(\.key))
        // Grows as shelves are built, so an item claimed by a higher tier
        // cannot reappear lower down.
        var claimed = Set<String>()

        let fromSections = feed.sections.map { section in
            RecommendationShelf(
                source: section.source,
                seedTitle: nil,
                items: section.items.map(ShelfItem.media)
            )
        }
        let fromCandidates = candidateShelves.map { shelf in
            RecommendationShelf(
                source: shelf.source,
                seedTitle: shelf.seedTitle,
                items: shelf.candidates.map(ShelfItem.candidate)
            )
        }

        let ordered = (fromSections + fromCandidates).sorted { left, right in
            (tierOrder.firstIndex(of: left.source) ?? tierOrder.count)
                < (tierOrder.firstIndex(of: right.source) ?? tierOrder.count)
        }

        var shelves: [RecommendationShelf] = []
        for shelf in ordered {
            if shelves.count >= maxShelves {
                break
            }

            var items: [ShelfItem] = []
            for item in shelf.items {
                if items.count >= maxShelfItems {
                    break
                }

                if item.hasCatalogIdentity {
                    if excluded.contains(item.id) || claimed.contains(item.id) {
                        continue
                    }
                    claimed.insert(item.id)
                }
                items.append(item)
            }

            if items.count >= minShelfItems {
                shelves.append(RecommendationShelf(
                    source: shelf.source,
                    seedTitle: shelf.seedTitle,
                    items: items
                ))
            }
        }

        return shelves
    }

    /// The same shelves, narrowed to one media kind.
    ///
    /// Explorer's per-kind tabs used to show the newest rows in the
    /// catalog — a list of what other people happened to log, which is the
    /// profile page's job, not a recommendation. Filtering the shelves we
    /// already built keeps every tab answering the question the All tab
    /// answers. Mirrors web's `shelvesForKind` (rule 17).
    ///
    /// Unlike `assemble`, a surviving shelf needs only one item rather than
    /// `minShelfItems`. Three is the bar when the whole catalog is in play;
    /// narrowed to books alone the realistic choice is two recommendations
    /// or none, and two beats an empty tab.
    static func shelves(
        _ shelves: [RecommendationShelf],
        for kind: MediaKind
    ) -> [RecommendationShelf] {
        shelves.compactMap { shelf in
            let items = shelf.items.filter { $0.mediaKind == kind }
            guard !items.isEmpty else { return nil }
            return RecommendationShelf(
                source: shelf.source,
                seedTitle: shelf.seedTitle,
                items: items
            )
        }
    }
}
