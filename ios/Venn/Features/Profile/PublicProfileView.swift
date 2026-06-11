import SwiftUI

/// Profile for another user, pushed from People search or a follow list.
/// Reuses the signed-in profile's building blocks (header, shelf tabs,
/// cover gallery) via the shared `ProfileViewModel`, plus the Follow /
/// Following button. The Venn overlap lands here next. Owner affordances
/// (edit, add, settings) and shelf tap-through stay absent.
struct PublicProfileView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AuthState.self)
    private var authState

    /// The search result that was tapped. Drives the navigation title
    /// immediately; the full snapshot (counts + shelves) loads async.
    let profile: UserProfile

    @State private var viewModel: ProfileViewModel?
    @State private var followViewModel: FollowViewModel?
    @State private var shelf: ProfileShelf = .collection
    @State private var followListDestination: FollowListDestination?

    var body: some View {
        Screen {
            content
        }
        .navigationTitle("@\(profile.username)")
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
        }
        .navigationDestination(item: $followListDestination) { destination in
            FollowListView(viewModel: FollowListViewModel(
                userID: destination.userID,
                kind: destination.kind,
                service: FollowService(client: clientProvider.client)
            ))
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading profile…")
            case let .loaded(snapshot):
                loadedView(snapshot)
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load this profile") {
                    Task { await viewModel.load() }
                }
            }
        } else {
            DeferredLoadingView()
        }
    }

    private func loadedView(_ snapshot: ProfileSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ProfileHeaderView(
                    name: snapshot.profile.displayName ?? snapshot.profile.username,
                    handle: snapshot.profile.username,
                    followers: snapshot.followCounts.followers,
                    following: snapshot.followCounts.following,
                    onTapFollowers: {
                        followListDestination = .init(userID: profile.id, kind: .followers)
                    },
                    onTapFollowing: {
                        followListDestination = .init(userID: profile.id, kind: .following)
                    }
                )
                if let bio = snapshot.profile.bio {
                    Text(verbatim: bio)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                followButton
                ShelfTabs(selection: $shelf)
                ProfileShelfGallery(
                    items: shelf == .collection ? snapshot.collection : snapshot.watchlist,
                    emptyMessage: shelf == .collection
                        ? "Nothing logged yet."
                        : "Nothing saved yet."
                )
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .scrollContentBackground(.hidden)
        .tracksGlassSkyParallax()
    }

    /// Follow / Following toggle. Hidden when nobody is signed in (the
    /// DEBUG design-preview boot) — there's no follower side for the edge.
    @ViewBuilder private var followButton: some View {
        if let followViewModel {
            if followViewModel.state == .following {
                SecondaryButton(title: "Following", isEnabled: !followViewModel.isWorking) {
                    Task { await toggleFollow() }
                }
            } else {
                PrimaryButton(
                    title: "Follow",
                    isLoading: followViewModel.isWorking
                ) {
                    Task { await toggleFollow() }
                }
            }
        }
    }

    private func toggleFollow() async {
        await followViewModel?.toggle()
        await viewModel?.refreshFollowCounts()
    }

    /// The signed-in user — the follower side of any edge created here.
    private var signedInUserID: UUID? {
        if case let .signedIn(session) = authState.status {
            session.user.id
        } else {
            nil
        }
    }

    private func ensureLoaded() async {
        if viewModel == nil {
            let viewModel = ProfileViewModel(
                userID: profile.id,
                service: ProfileService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load()
        }
        if followViewModel == nil, let userID = signedInUserID, userID != profile.id {
            let followViewModel = FollowViewModel(
                followerID: userID,
                followeeID: profile.id,
                service: FollowService(client: clientProvider.client)
            )
            self.followViewModel = followViewModel
            await followViewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        PublicProfileView(profile: UserProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            username: "maya",
            displayName: "Maya Chen",
            avatarURL: nil,
            bio: "Logging everything I watch, read, and hear.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))
    }
    .environment(SupabaseClientProvider.preview)
    .environment(AuthState(service: AuthService(client: SupabaseClientProvider.preview.client)))
}
