import Foundation
import Testing
@testable import Venn

@MainActor
struct FollowRequestsViewModelTests {
    @Test
    func loadsPendingRequests() async {
        let ada = makeProfile(username: "ada")
        let service = FakeFollowService()
        service.pendingRequestsResult = .success([ada])
        let viewModel = FollowRequestsViewModel(userID: UUID(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded([ada]))
    }

    @Test
    func networkFailureMapsToOffline() async {
        let service = FakeFollowService()
        service.pendingRequestsResult = .failure(AppError.network)
        let viewModel = FollowRequestsViewModel(userID: UUID(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func acceptOptimisticallyRemovesTheRequest() async {
        let ada = makeProfile(username: "ada")
        let maya = makeProfile(username: "maya")
        let service = FakeFollowService()
        service.pendingRequestsResult = .success([ada, maya])
        let viewModel = FollowRequestsViewModel(userID: UUID(), service: service)
        await viewModel.load()

        await viewModel.respond(to: ada, accept: true)

        #expect(viewModel.state == .loaded([maya]))
        #expect(service.respondCalls == 1)
    }

    @Test
    func rejectOptimisticallyRemovesTheRequest() async {
        let ada = makeProfile(username: "ada")
        let service = FakeFollowService()
        service.pendingRequestsResult = .success([ada])
        let viewModel = FollowRequestsViewModel(userID: UUID(), service: service)
        await viewModel.load()

        await viewModel.respond(to: ada, accept: false)

        #expect(viewModel.state == .loaded([]))
        #expect(service.respondCalls == 1)
    }

    @Test
    func failedResponseReloadsAndRestoresTheRequest() async {
        let ada = makeProfile(username: "ada")
        let service = FakeFollowService()
        service.pendingRequestsResult = .success([ada])
        let viewModel = FollowRequestsViewModel(userID: UUID(), service: service)
        await viewModel.load()

        service.respondResult = .failure(AppError.network)
        await viewModel.respond(to: ada, accept: true)

        #expect(viewModel.state == .loaded([ada]))
    }

    @Test
    func respondDoesNothingWhenNotInLoadedState() async {
        let service = FakeFollowService()
        let viewModel = FollowRequestsViewModel(userID: UUID(), service: service)
        // State is .loading — respond should be a no-op.

        await viewModel.respond(to: makeProfile(username: "ada"), accept: true)

        #expect(service.respondCalls == 0)
    }

    private func makeProfile(username: String) -> UserProfile {
        UserProfile(
            id: UUID(),
            username: username,
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
