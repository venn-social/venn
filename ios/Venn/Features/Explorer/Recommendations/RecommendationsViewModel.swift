import Foundation
import Observation

/// Drives the recommendation shelves above Explorer's browse grid.
///
/// Uses the shared `LoadState` machine rather than a per-feature enum
/// (docs/ARCHITECTURE.md, "The standard load pattern").
@MainActor
@Observable
final class RecommendationsViewModel {
    typealias State = LoadState<[RecommendationShelf]>

    private(set) var state: State = .loading

    private let service: any RecommendationServicing
    private let catalog: any CatalogSimilarServicing

    init(service: any RecommendationServicing, catalog: any CatalogSimilarServicing) {
        self.service = service
        self.catalog = catalog
    }

    func load() async {
        state = .loading
        do {
            let feed = try await service.feed()
            state = await .loaded(shelves(for: feed))
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// Catalog failures cost one shelf each, never the page: the providers
    /// are independent of each other and of the RPC, so one being down
    /// should thin the screen rather than blank it. Only the RPC itself
    /// failing is an error state, and even then Explorer's browse grid
    /// still renders below.
    private func shelves(for feed: RecommendationFeed) async -> [RecommendationShelf] {
        var candidateShelves: [CandidateShelf] = []

        for seed in feed.seeds {
            let candidates = await (try? catalog.similar(to: seed)) ?? []
            candidateShelves.append(CandidateShelf(
                source: .similar,
                seedTitle: seed.title,
                candidates: candidates
            ))
        }

        let trending = await (try? catalog.trending()) ?? []
        candidateShelves.append(CandidateShelf(
            source: .trending,
            seedTitle: nil,
            candidates: trending
        ))

        return RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: candidateShelves
        )
    }
}
