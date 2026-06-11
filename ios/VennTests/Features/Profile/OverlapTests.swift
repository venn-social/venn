import Foundation
import Testing
@testable import Venn

/// Tests for the overlap wire format, the summary aggregation, and the
/// view-model state machine. The SQL itself runs server-side; the decode
/// test pins the row shape `compute_overlap` returns.
struct OverlapTests {
    @Test
    func decodesKindOverlapRow() throws {
        let json = Data("""
        [{ "kind": "movie", "viewer_count": 12, "other_count": 8, "shared_count": 3 }]
        """.utf8)

        let rows = try JSONDecoder().decode([KindOverlap].self, from: json)

        #expect(rows == [
            KindOverlap(kind: .movie, viewerCount: 12, otherCount: 8, sharedCount: 3),
        ])
    }

    @Test
    func summarySumsAcrossKinds() {
        let summary = OverlapSummary(kinds: [
            KindOverlap(kind: .movie, viewerCount: 12, otherCount: 8, sharedCount: 3),
            KindOverlap(kind: .book, viewerCount: 5, otherCount: 9, sharedCount: 2),
            KindOverlap(kind: .album, viewerCount: 0, otherCount: 4, sharedCount: 0),
        ])

        #expect(summary.viewerTotal == 17)
        #expect(summary.otherTotal == 21)
        #expect(summary.sharedTotal == 5)
    }

    @Test
    func summaryOfNothingIsAllZeros() {
        let summary = OverlapSummary(kinds: [])
        #expect(summary.viewerTotal == 0)
        #expect(summary.otherTotal == 0)
        #expect(summary.sharedTotal == 0)
    }
}

@MainActor
struct OverlapViewModelTests {
    @Test
    func loadSuccessTransitionsToLoaded() async {
        let summary = OverlapSummary(kinds: [
            KindOverlap(kind: .movie, viewerCount: 2, otherCount: 2, sharedCount: 1),
        ])
        let service = FakeOverlapService()
        service.result = .success(summary)
        let viewModel = OverlapViewModel(otherUserID: UUID(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded(summary))
    }

    @Test
    func rateLimitedMapsToRateLimitedReason() async {
        let service = FakeOverlapService()
        service.result = .failure(AppError.rateLimited)
        let viewModel = OverlapViewModel(otherUserID: UUID(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.rateLimited))
    }

    @Test
    func networkFailureMapsToOffline() async {
        let service = FakeOverlapService()
        service.result = .failure(AppError.network)
        let viewModel = OverlapViewModel(otherUserID: UUID(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }
}

// MARK: - Fake

final class FakeOverlapService: OverlapServicing, @unchecked Sendable {
    var result: Result<OverlapSummary, Error> = .success(OverlapSummary(kinds: []))

    func overlap(with _: UUID) async throws -> OverlapSummary {
        try result.get()
    }
}
