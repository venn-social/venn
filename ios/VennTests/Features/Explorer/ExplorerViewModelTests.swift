import Foundation
import Testing
@testable import Venn

@MainActor
struct ExplorerViewModelTests {
    @Test
    func initialStateIsLoading() {
        let viewModel = ExplorerViewModel(service: FakeExplorerService())
        #expect(viewModel.state == .loading)
    }

    @Test
    func loadSuccessTransitionsToLoaded() async {
        let media = [makeMedia(title: "Past Lives", kind: .movie)]
        let service = FakeExplorerService()
        service.result = .success(media)
        let viewModel = ExplorerViewModel(service: service)

        await viewModel.load(kind: .movie)

        #expect(viewModel.state == .loaded(media))
        #expect(service.lastRequestedKind == .movie)
    }

    @Test
    func loadEmptyResultStillTransitionsToLoadedWithEmptyArray() async {
        // Empty catalog for a kind is a valid loaded state, not an error.
        // View renders the empty-state copy off this.
        let service = FakeExplorerService()
        service.result = .success([])
        let viewModel = ExplorerViewModel(service: service)

        await viewModel.load(kind: .book)

        #expect(viewModel.state == .loaded([]))
    }

    @Test
    func loadFailureWithAppErrorNetworkMapsToOffline() async {
        let viewModel = makeViewModel(failingWith: AppError.network)

        await viewModel.load(kind: .album)

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func loadFailureWithNonAppErrorFallsBackToUnknown() async {
        struct Boom: Error {}
        let viewModel = makeViewModel(failingWith: Boom())

        await viewModel.load(kind: .movie)

        #expect(viewModel.state == .error(.unknown))
    }

    @Test
    func reloadWithDifferentKindReissuesTheQuery() async {
        // Category-switch path: same viewmodel, different kind, must
        // re-hit the service with the new value.
        let service = FakeExplorerService()
        service.result = .success([makeMedia(title: "Past Lives", kind: .movie)])
        let viewModel = ExplorerViewModel(service: service)

        await viewModel.load(kind: .movie)
        await viewModel.load(kind: .book)

        #expect(service.kindCallLog == [.movie, .book])
    }

    // MARK: - helpers

    private func makeViewModel(failingWith error: any Error) -> ExplorerViewModel {
        let service = FakeExplorerService()
        service.result = .failure(error)
        return ExplorerViewModel(service: service)
    }

    private func makeMedia(title: String, kind: MediaKind) -> Media {
        Media(
            id: .init(),
            kind: kind,
            title: title,
            year: 2023,
            primaryCreator: "Test Creator",
            coverURL: nil,
            externalID: nil,
            externalSource: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

final class FakeExplorerService: ExplorerServicing, @unchecked Sendable {
    var result: Result<[Media], Error> = .failure(NotConfigured())
    private(set) var lastRequestedKind: MediaKind?
    private(set) var kindCallLog: [MediaKind] = []

    func recentMedia(kind: MediaKind, limit _: Int) async throws -> [Media] {
        lastRequestedKind = kind
        kindCallLog.append(kind)
        return try result.get()
    }

    private struct NotConfigured: Error {}
}
