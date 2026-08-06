import Foundation
import Testing
@testable import Venn

/// Searching the catalog and appending a result to a list.
///
/// The behaviour worth pinning down is the two-step write: a catalog result
/// nobody has logged exists nowhere in our database, so it must reach
/// `public.media` before `list_items` can reference it.
@MainActor
struct ListAddViewModelTests {
    @Test
    func addingUpsertsTheCatalogRowBeforeTheListItem() async {
        // Without the upsert this fails on a foreign key — `list_items`
        // references `public.media`, and an unlogged film has no row there.
        let catalog = FakeComposerService()
        catalog.upsertResult = .success(Self.mediaID)
        let lists = FakeListsService(lists: [])
        let viewModel = Self.viewModel(catalog: catalog, lists: lists)

        await viewModel.add(Self.candidate)

        #expect(catalog.upsertCallCount == 1)
        #expect(lists.addedPositions == [0])
    }

    @Test
    func appendsAfterTheExistingItems() async {
        let catalog = FakeComposerService()
        catalog.upsertResult = .success(Self.mediaID)
        let lists = FakeListsService(lists: [])
        lists.itemPositions = [0, 1, 2, 3]
        let viewModel = Self.viewModel(catalog: catalog, lists: lists)

        await viewModel.add(Self.candidate)

        #expect(lists.addedPositions == [4])
    }

    @Test
    func addingTheSameCandidateTwiceIsOneWrite() async {
        let catalog = FakeComposerService()
        catalog.upsertResult = .success(Self.mediaID)
        let lists = FakeListsService(lists: [])
        let viewModel = Self.viewModel(catalog: catalog, lists: lists)

        await viewModel.add(Self.candidate)
        await viewModel.add(Self.candidate)

        #expect(lists.addedPositions.count == 1)
        #expect(viewModel.added.contains(Self.candidate.id))
    }

    @Test
    func aFailedUpsertNeverWritesAListItem() async {
        // The order matters: a list row pointing at a media row that was
        // never created is the corruption this guards against.
        let catalog = FakeComposerService()
        catalog.upsertResult = .failure(AppError.network)
        let lists = FakeListsService(lists: [])
        let viewModel = Self.viewModel(catalog: catalog, lists: lists)

        await viewModel.add(Self.candidate)

        #expect(lists.addedPositions.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.added.contains(Self.candidate.id))
    }

    @Test
    func anEmptyQueryGoesBackToIdleWithoutSearching() {
        let catalog = FakeComposerService()
        let viewModel = Self.viewModel(catalog: catalog, lists: FakeListsService(lists: []))

        viewModel.search("   ")

        #expect(viewModel.searchState == .idle)
    }

    @Test
    func searchingReturnsCandidates() async {
        let catalog = FakeComposerService()
        catalog.searchResult = .success([Self.candidate])
        let viewModel = Self.viewModel(catalog: catalog, lists: FakeListsService(lists: []))

        viewModel.search("past lives")
        try? await Task.sleep(for: .milliseconds(60))

        #expect(viewModel.searchState == .results([Self.candidate]))
    }

    @Test
    func aSearchFailureMapsToTheSharedErrorReason() async {
        let catalog = FakeComposerService()
        catalog.searchResult = .failure(AppError.network)
        let viewModel = Self.viewModel(catalog: catalog, lists: FakeListsService(lists: []))

        viewModel.search("past lives")
        try? await Task.sleep(for: .milliseconds(60))

        #expect(viewModel.searchState == .error(.offline))
    }

    @Test
    func switchingKindResearchesTheSameQuery() async {
        // Otherwise the chips look interactive but leave stale film results
        // on screen after switching to Books.
        let catalog = FakeComposerService()
        catalog.searchResult = .success([Self.candidate])
        let viewModel = Self.viewModel(catalog: catalog, lists: FakeListsService(lists: []))

        viewModel.search("past lives")
        try? await Task.sleep(for: .milliseconds(60))
        viewModel.kind = .book
        try? await Task.sleep(for: .milliseconds(60))

        #expect(catalog.searchCallCount == 2)
    }

    // MARK: - Fixtures

    private static let mediaID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    ) ?? UUID()

    private static let candidate = MediaCandidate(
        title: "Past Lives",
        primaryCreator: "Celine Song",
        year: 2023,
        coverURL: nil,
        overview: nil,
        externalID: "666277",
        externalSource: .tmdb,
        kind: .movie
    )

    private static func viewModel(
        catalog: FakeComposerService,
        lists: FakeListsService
    ) -> ListAddViewModel {
        ListAddViewModel(
            listID: UUID(),
            catalog: catalog,
            lists: lists,
            // Near-zero so the tests don't wait on the real debounce.
            debounce: .milliseconds(1)
        )
    }
}
