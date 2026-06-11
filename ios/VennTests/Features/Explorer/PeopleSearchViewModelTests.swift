import Foundation
import Testing
@testable import Venn

/// Tests for the people-search state machine. All lookups go through
/// FakePeopleSearchService — no network. Debounce is set to zero so the
/// async transitions settle immediately.
@MainActor
struct PeopleSearchViewModelTests {
    @Test
    func initialStateIsIdle() {
        let viewModel = makeViewModel(service: FakePeopleSearchService())
        #expect(viewModel.state == .idle)
    }

    @Test
    func emptyQueryResetsToIdle() {
        let viewModel = makeViewModel(service: FakePeopleSearchService())
        viewModel.search("")
        #expect(viewModel.state == .idle)
    }

    @Test
    func whitespaceQueryResetsToIdle() {
        let viewModel = makeViewModel(service: FakePeopleSearchService())
        viewModel.search("   ")
        #expect(viewModel.state == .idle)
    }

    @Test
    func queryFlipsToSearchingImmediately() {
        let viewModel = makeViewModel(service: FakePeopleSearchService())
        viewModel.search("ada")
        #expect(viewModel.state == .searching)
    }

    @Test
    func successTransitionsToResults() async {
        let ada = makeProfile(username: "ada")
        let service = FakePeopleSearchService()
        service.result = .success([ada])
        let viewModel = makeViewModel(service: service)

        viewModel.search("ada")
        await waitForSettle(viewModel)

        #expect(viewModel.state == .results([ada]))
        #expect(service.lastQuery == "ada")
    }

    @Test
    func resultsExcludeTheSignedInUser() async {
        let me = makeProfile(username: "me")
        let ada = makeProfile(username: "ada")
        let service = FakePeopleSearchService()
        service.result = .success([ada, me])
        let viewModel = makeViewModel(service: service, currentUserID: me.id)

        viewModel.search("a")
        await waitForSettle(viewModel)

        #expect(viewModel.state == .results([ada]))
    }

    @Test
    func emptyMatchesStillTransitionToResults() async {
        // "No results" is a valid outcome, not an error — the view renders
        // empty-state copy off this.
        let service = FakePeopleSearchService()
        service.result = .success([])
        let viewModel = makeViewModel(service: service)

        viewModel.search("zzz")
        await waitForSettle(viewModel)

        #expect(viewModel.state == .results([]))
    }

    @Test
    func networkErrorMapsToOffline() async {
        let service = FakePeopleSearchService()
        service.result = .failure(AppError.network)
        let viewModel = makeViewModel(service: service)

        viewModel.search("ada")
        await waitForSettle(viewModel)

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func nonAppErrorFallsBackToUnknown() async {
        struct Boom: Error {}
        let service = FakePeopleSearchService()
        service.result = .failure(Boom())
        let viewModel = makeViewModel(service: service)

        viewModel.search("ada")
        await waitForSettle(viewModel)

        #expect(viewModel.state == .error(.unknown))
    }

    @Test
    func clearResetsToIdle() {
        let viewModel = makeViewModel(service: FakePeopleSearchService())
        viewModel.search("ada")
        viewModel.clear()
        #expect(viewModel.state == .idle)
    }

    // MARK: - Helpers

    private func makeViewModel(
        service: FakePeopleSearchService,
        currentUserID: UUID? = nil
    ) -> PeopleSearchViewModel {
        PeopleSearchViewModel(service: service, currentUserID: currentUserID, debounce: .zero)
    }

    /// Yield until the debounced search task has run (debounce is zero, so a
    /// few hops of the main actor are enough).
    private func waitForSettle(_ viewModel: PeopleSearchViewModel) async {
        for _ in 0..<20 {
            if viewModel.state != .searching { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func makeProfile(username: String) -> UserProfile {
        UserProfile(
            id: UUID(),
            username: username,
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

// MARK: - Fake

final class FakePeopleSearchService: PeopleSearchServicing, @unchecked Sendable {
    var result: Result<[UserProfile], Error> = .success([])
    private(set) var lastQuery: String?
    private(set) var lastLimit: Int?

    func searchProfiles(matching query: String, limit: Int) async throws -> [UserProfile] {
        lastQuery = query
        lastLimit = limit
        return try result.get()
    }
}
