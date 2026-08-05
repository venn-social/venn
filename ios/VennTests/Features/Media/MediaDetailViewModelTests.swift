import Foundation
import Testing
@testable import Venn

/// `MediaDetailViewModel` against a fake service. The mapping has its own
/// tests (`MediaDetailMappingTests`); these cover the state machine and the
/// hand-off to the composer.
@MainActor
struct MediaDetailViewModelTests {
    @Test
    func loadsDetailForTheCatalogRow() async {
        var detail = MediaDetail()
        detail.overview = "Two friends reunite."
        let service = FakeMediaDetailService(detail: detail)
        let viewModel = MediaDetailViewModel(
            media: Self.movie,
            service: service,
            region: "GB"
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded(detail))
    }

    @Test
    func passesTheRequestedRegionThrough() async {
        // Availability is regional; asking for the wrong country is a wrong
        // answer, not a missing one.
        let service = FakeMediaDetailService(detail: .empty)
        let viewModel = MediaDetailViewModel(media: Self.movie, service: service, region: "FR")

        await viewModel.load()

        #expect(service.regions == ["FR"])
    }

    @Test
    func mapsAFailureToTheSharedErrorReason() async {
        let service = FakeMediaDetailService(detail: .empty)
        service.error = AppError.network
        let viewModel = MediaDetailViewModel(media: Self.movie, service: service, region: "GB")

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func buildsAComposerCandidateFromTheCatalogRow() async {
        var detail = MediaDetail()
        detail.overview = "Two friends reunite."
        let viewModel = MediaDetailViewModel(
            media: Self.movie,
            service: FakeMediaDetailService(detail: detail),
            region: "GB"
        )

        await viewModel.load()
        let candidate = viewModel.logCandidate

        #expect(candidate?.title == "Past Lives")
        #expect(candidate?.externalID == "666277")
        #expect(candidate?.externalSource == .tmdb)
        #expect(candidate?.kind == .movie)
        // The overview the provider just returned rides along, so the
        // composer's confirm step isn't blank.
        #expect(candidate?.overview == "Two friends reunite.")
    }

    @Test
    func offersNoCandidateForAHandTypedRow() async {
        // Without an external identity there is nothing for the composer to
        // de-duplicate against, so "Log this" must not be offered at all.
        let handTyped = Media(
            id: UUID(),
            kind: .book,
            title: "A friend's zine",
            year: nil,
            primaryCreator: nil,
            coverURL: nil,
            externalID: nil,
            externalSource: nil,
            createdAt: .now
        )
        let viewModel = MediaDetailViewModel(
            media: handTyped,
            service: FakeMediaDetailService(detail: .empty),
            region: "GB"
        )

        await viewModel.load()

        #expect(viewModel.logCandidate == nil)
    }

    // MARK: - Fixtures

    private static let movie = Media(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
        kind: .movie,
        title: "Past Lives",
        year: 2023,
        primaryCreator: "Celine Song",
        coverURL: nil,
        externalID: "666277",
        externalSource: .tmdb,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

/// Records the regions it was asked for so tests can assert the device
/// region actually reaches the provider. Set `error` to fail the call.
final class FakeMediaDetailService: MediaDetailServicing, @unchecked Sendable {
    let detail: MediaDetail
    var error: AppError?
    private(set) var regions: [String] = []

    init(detail: MediaDetail) {
        self.detail = detail
    }

    func detail(for _: Media, region: String) async throws -> MediaDetail {
        regions.append(region)
        if let error {
            throw error
        }
        return detail
    }
}
