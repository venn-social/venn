import Foundation
import Testing
@testable import Venn

@MainActor
struct FollowListViewModelTests {
    @Test
    func loadsFollowers() async {
        let ada = makeProfile(username: "ada")
        let service = FakeFollowService()
        service.followersResult = .success([ada])
        let viewModel = FollowListViewModel(userID: UUID(), kind: .followers, service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded([ada]))
    }

    @Test
    func loadsFollowing() async {
        let maya = makeProfile(username: "maya")
        let service = FakeFollowService()
        service.followingResult = .success([maya])
        let viewModel = FollowListViewModel(userID: UUID(), kind: .following, service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded([maya]))
    }

    @Test
    func networkFailureMapsToOffline() async {
        let service = FakeFollowService()
        service.followersResult = .failure(AppError.network)
        let viewModel = FollowListViewModel(userID: UUID(), kind: .followers, service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func listKindsCarryTheirNavigationTitles() {
        #expect(FollowListKind.followers.title == "Followers")
        #expect(FollowListKind.following.title == "Following")
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
