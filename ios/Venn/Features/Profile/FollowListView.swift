import SwiftUI

/// Which side of the follow graph a `FollowListView` shows.
enum FollowListKind: Hashable {
    case followers
    case following

    var title: String {
        switch self {
        case .followers: "Followers"
        case .following: "Following"
        }
    }
}

/// Value pushed onto a `NavigationStack` when a follower/following count
/// is tapped.
struct FollowListDestination: Hashable {
    let userID: UUID
    let kind: FollowListKind
}

/// Loads one side of a user's follow graph and exposes it through the
/// standard `LoadState` machine.
@MainActor
@Observable
final class FollowListViewModel {
    typealias State = LoadState<[UserProfile]>

    private(set) var state: State = .loading

    let userID: UUID
    let kind: FollowListKind
    private let service: any FollowServicing

    init(userID: UUID, kind: FollowListKind, service: any FollowServicing) {
        self.userID = userID
        self.kind = kind
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let profiles = switch kind {
            case .followers:
                try await service.followers(of: userID, limit: 50)
            case .following:
                try await service.following(of: userID, limit: 50)
            }
            state = .loaded(profiles)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}

/// Full-screen list of one side of a user's follow graph. Pushed from the
/// follower/following counts on either profile screen; rows push the
/// person's public profile.
struct FollowListView: View {
    @State var viewModel: FollowListViewModel

    var body: some View {
        Screen {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading…")
            case let .loaded(profiles):
                if profiles.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(profiles) { profile in
                                NavigationLink(value: profile) {
                                    ProfileRow(profile: profile)
                                }
                                .buttonStyle(.plain)
                                .vennScrollDepth()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.lg)
                    }
                    .scrollContentBackground(.hidden)
                }
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load the list") {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle(viewModel.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
        }
        .task { await viewModel.load() }
    }

    private var emptyView: some View {
        EmptyStateView(
            systemImage: "person.2",
            title: viewModel.kind == .followers ? "No followers yet" : "Not following anyone yet",
            message: viewModel.kind == .followers
                ? "Followers will show up here."
                : "Find people in the Explorer tab to start building the graph."
        )
    }
}
