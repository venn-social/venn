import SwiftUI

/// Profile for another user, pushed from People search or a follow list.
/// Reuses the signed-in profile's building blocks (header, shelf tabs,
/// cover gallery) via the shared `ProfileViewModel`, plus the two surfaces
/// that only exist for someone else: the Follow / Following button and the
/// "Your Venn" taste overlap. Owner affordances (edit, add, settings) and
/// shelf tap-through stay absent.
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
    @State private var overlapViewModel: OverlapViewModel?
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
                overlapSection
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

    // MARK: - Overlap ("Your Venn")

    /// The product's signature: how the viewer's taste intersects this
    /// person's. Only renders for a signed-in viewer on someone else's
    /// profile — same condition as the follow button.
    @ViewBuilder private var overlapSection: some View {
        if let overlapViewModel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Your Venn")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Color.textPrimary)

                switch overlapViewModel.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                case let .loaded(summary):
                    overlapContent(summary)
                case .error:
                    HStack {
                        Text("Couldn't load your Venn.")
                            .font(Theme.Font.callout)
                            .foregroundStyle(Theme.Color.textSecondary)
                        Spacer()
                        Button("Try again") {
                            Task { await overlapViewModel.load() }
                        }
                        .font(Theme.Font.callout.weight(.semibold))
                        .foregroundStyle(Theme.Color.accent)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    @ViewBuilder
    private func overlapContent(_ summary: OverlapSummary) -> some View {
        if summary.viewerTotal == 0, summary.otherTotal == 0 {
            Text("Log a few things and your shared taste shows up here.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        } else {
            VStack(spacing: Theme.Spacing.md) {
                VennOverlap(mode: .pair(
                    yours: .init(label: "Only you", count: summary.viewerTotal),
                    theirs: .init(label: "Only @\(profile.username)", count: summary.otherTotal),
                    shared: summary.sharedTotal
                ))
                .frame(maxWidth: .infinity)

                sharedKindRows(summary)
            }
        }
    }

    /// One row per kind with shared items — "Movies in common · 3".
    @ViewBuilder
    private func sharedKindRows(_ summary: OverlapSummary) -> some View {
        let shared = summary.kinds.filter { $0.sharedCount > 0 }
        if !shared.isEmpty {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(shared, id: \.kind) { slice in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: slice.kind.systemImage)
                            .font(.caption)
                            .foregroundStyle(Theme.Color.accent)
                        Text(verbatim: "\(slice.kind.displayName.capitalized)s in common")
                            .font(Theme.Font.callout)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Spacer()
                        Text(verbatim: "\(slice.sharedCount)")
                            .font(Theme.Font.callout.weight(.semibold))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .monospacedDigit()
                    }
                }
            }
        }
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
            let overlapViewModel = OverlapViewModel(
                otherUserID: profile.id,
                service: OverlapService(client: clientProvider.client)
            )
            self.overlapViewModel = overlapViewModel
            await followViewModel.load()
            await overlapViewModel.load()
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
