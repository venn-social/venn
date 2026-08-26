import SwiftUI

/// Profile for another user, pushed from People search or a follow list.
/// Reuses the signed-in profile's building blocks (header, shelf tabs,
/// cover gallery) via the shared `ProfileViewModel`, plus the two surfaces
/// that only exist for someone else: the Follow / Following button and the
/// the taste overlap. Owner affordances (edit, add, settings) and
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
            Theme.Color.background
        }
        .navigationDestination(item: $followListDestination) { destination in
            FollowListView(viewModel: FollowListViewModel(
                userID: destination.userID,
                kind: destination.kind,
                service: FollowService(client: clientProvider.client)
            ))
        }
        // No `.navigationDestination(for: Media.self)` here on purpose: both
        // stacks this screen is pushed onto (Profile and Explorer) already
        // register one, and a second declaration on the same stack is
        // ignored with a runtime warning.
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
                    avatarURL: snapshot.profile.avatarURL,
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
                if isLocked(snapshot) {
                    lockedContent
                } else {
                    overlapSection
                    ShelfTabs(selection: $shelf)
                    ProfileShelfGallery(
                        items: shelf == .collection ? snapshot.collection : snapshot.watchlist,
                        emptyMessage: shelf == .collection
                            ? "Nothing logged yet."
                            : "Nothing saved yet."
                    )
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .scrollContentBackground(.hidden)
        .tracksGlassSkyParallax()
    }

    /// True when RLS is actually hiding this person's posts from the
    /// viewer: a private account, and not (yet) an accepted follower. A
    /// `nil` followViewModel (no signed-in viewer) defaults to locked —
    /// matches what an unauthenticated request would actually see.
    private func isLocked(_ snapshot: ProfileSnapshot) -> Bool {
        guard snapshot.profile.isPrivate else { return false }
        return followViewModel?.state != .following
    }

    /// Shown instead of the overlap section and shelves when the account
    /// is private and the viewer isn't an accepted follower yet — the
    /// shelves would otherwise just render as empty and read as "this
    /// person hasn't logged anything," which is misleading.
    private var lockedContent: some View {
        EmptyStateView(
            systemImage: "lock.fill",
            title: "This account is private",
            message: "Follow @\(profile.username) to see their posts and your taste overlap."
        )
    }

    /// Follow / Requested / Following toggle. Hidden when nobody is signed
    /// in (the DEBUG design-preview boot) — there's no follower side for
    /// the edge. "Requested" reuses the "Following" secondary-button
    /// treatment (styling polish for the locked-content state that goes
    /// with it lands separately).
    /// Follow / Requested / Following, as one compact pill on the page's
    /// own ground. Mirrors web (rule 17).
    ///
    /// Deliberately not `PrimaryButton`: an accent-filled, full-width
    /// button made Follow the loudest thing on someone's profile, above
    /// the person and above what they like, which is not the order of
    /// importance. The states differ by weight of text, not by a block of
    /// colour. `SecondaryButton` is left alone — it is shared with Cancel
    /// and Skip, which do want that footprint.
    @ViewBuilder private var followButton: some View {
        if let followViewModel {
            let isFollowing = followViewModel.state != .notFollowing
            let title: LocalizedStringKey = switch followViewModel.state {
            case .following: "Following"
            case .requested: "Requested"
            case .notFollowing: "Follow"
            }

            Button {
                Task { await toggleFollow() }
            } label: {
                Text(title)
                    .font(
                        isFollowing
                            ? Theme.Font.footnote
                            : Theme.Font.footnote.weight(.semibold)
                    )
                    .foregroundStyle(
                        isFollowing ? Theme.Color.textSecondary : Theme.Color.textPrimary
                    )
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.background, in: .capsule)
                    .overlay {
                        Capsule().strokeBorder(Theme.Color.separator, lineWidth: 1)
                    }
                    .opacity(followViewModel.isWorking ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(followViewModel.isWorking)
            .accessibilityIdentifier("follow_button")
        }
    }

    private func toggleFollow() async {
        await followViewModel?.toggle()
        await viewModel?.refreshFollowCounts()
    }

    // MARK: - Overlap

    /// The product's signature: how the viewer's taste intersects this
    /// person's. Only renders for a signed-in viewer on someone else's
    /// profile — same condition as the follow button.
    @ViewBuilder private var overlapSection: some View {
        if let overlapViewModel {
            // No heading. A Venn diagram of two people's taste does not
            // need to be labelled "Your Venn" on a screen that is already
            // one person's profile seen from another's.
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                switch overlapViewModel.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                case let .loaded(summary):
                    overlapContent(summary)
                case .error:
                    HStack {
                        Text("Couldn't load the overlap.")
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

    /// The shared kinds, as one line — "7 movies · 4 albums · 1 book".
    ///
    /// A row each, with an icon and a right-aligned count, was a table
    /// restating what the diagram had already totalled. This says only
    /// what kind of thing was shared.
    @ViewBuilder
    private func sharedKindRows(_ summary: OverlapSummary) -> some View {
        let shared = summary.kinds.filter { $0.sharedCount > 0 }
        if !shared.isEmpty {
            Text(verbatim: shared
                .map { "\($0.sharedCount) \($0.kind.displayName)\($0.sharedCount == 1 ? "" : "s")" }
                .joined(separator: " · "))
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

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
