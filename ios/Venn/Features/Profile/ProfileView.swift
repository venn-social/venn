import SwiftUI

/// Profile tab. Loads the signed-in user's profile from Supabase and renders
/// the identity header, follow counts, primary actions, and a Collection /
/// Watchlist cover gallery. Tapping a shelf opens the full, editable
/// `LibraryListView`. Share + settings live in a top bar; both, like the Add
/// and Edit buttons, are wired in a later pass.
struct ProfileView: View {
    @Environment(AuthState.self)
    private var authState
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: ProfileViewModel?
    @State private var editViewModel: ProfileEditViewModel?
    @State private var shelf: ProfileShelf = .collection
    @State private var libraryDestination: LibraryDestination?
    @State private var followListDestination: FollowListDestination?

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .sheet(
                    isPresented: Binding(
                        get: { editViewModel != nil },
                        set: {
                            if !$0 {
                                editViewModel = nil
                            }
                        }
                    )
                ) {
                    if let editViewModel {
                        ProfileEditView(
                            viewModel: editViewModel,
                            onSaved: {
                                self.editViewModel = nil
                                Task { await viewModel?.load() }
                            },
                            onCancel: { self.editViewModel = nil }
                        )
                    }
                }
                .containerBackground(for: .navigation) {
                    GlassSkyBackground()
                }
                .navigationDestination(item: $libraryDestination) { dest in
                    LibraryListView(viewModel: makeLibraryViewModel(for: dest))
                }
                .navigationDestination(item: $followListDestination) { destination in
                    FollowListView(viewModel: FollowListViewModel(
                        userID: destination.userID,
                        kind: destination.kind,
                        service: FollowService(client: clientProvider.client)
                    ))
                }
                .navigationDestination(for: UserProfile.self) { profile in
                    PublicProfileView(profile: profile)
                }
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading your profile…")
            case let .loaded(snapshot):
                loadedView(snapshot)
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load your profile") {
                    Task { await viewModel.load() }
                }
            }
        } else {
            DeferredLoadingView()
        }
    }

    private func loadedView(_ snapshot: ProfileSnapshot) -> some View {
        let profile = snapshot.profile
        return Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    topBar
                    ProfileHeaderView(
                        name: profile.displayName ?? profile.username,
                        handle: profile.username,
                        avatarURL: profile.avatarURL,
                        followers: snapshot.followCounts.followers,
                        following: snapshot.followCounts.following,
                        onTapFollowers: {
                            followListDestination = .init(userID: profile.id, kind: .followers)
                        },
                        onTapFollowing: {
                            followListDestination = .init(userID: profile.id, kind: .following)
                        }
                    )
                    actionButtons
                    ShelfTabs(selection: $shelf)
                    shelfGallery(snapshot)
                }
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
            .tracksGlassSkyParallax()
        }
    }

    private var topBar: some View {
        HStack {
            iconButton("square.and.arrow.up", label: "Share") {}
            Spacer()
            iconButton("gearshape", label: "Settings") {}
        }
    }

    private func iconButton(
        _ systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .accessibilityLabel(label)
    }

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            PrimaryButton(title: "Add") {}
            SecondaryButton(title: "Edit profile") { presentEditSheet() }
        }
    }

    private func shelfGallery(_ snapshot: ProfileSnapshot) -> some View {
        ProfileShelfGallery(
            items: shelf == .collection ? snapshot.collection : snapshot.watchlist,
            emptyMessage: shelf == .collection
                ? "Nothing in your collection yet."
                : "Your watchlist is empty."
        ) {
            libraryDestination = LibraryDestination(
                userID: snapshot.profile.id,
                kind: nil,
                shelf: shelf
            )
        }
    }

    private func presentEditSheet() {
        guard let viewModel,
              case let .loaded(snapshot) = viewModel.state
        else {
            return
        }
        let profile = snapshot.profile
        editViewModel = ProfileEditViewModel(
            userID: profile.id,
            displayName: profile.displayName,
            bio: profile.bio,
            avatarURL: profile.avatarURL,
            service: ProfileService(client: clientProvider.client)
        )
    }

    private func makeLibraryViewModel(for dest: LibraryDestination) -> LibraryViewModel {
        LibraryViewModel(
            userID: dest.userID,
            kind: dest.kind,
            shelf: dest.shelf,
            service: ProfileService(client: clientProvider.client)
        )
    }

    private func ensureLoaded() async {
        if viewModel == nil, case let .signedIn(session) = authState.status {
            let viewModel = ProfileViewModel(
                userID: session.user.id,
                service: ProfileService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load()
        }
    }
}

/// Value pushed onto the `NavigationStack` when a shelf is tapped — everything
/// `LibraryViewModel` needs to load the full, editable list.
struct LibraryDestination: Hashable {
    let userID: UUID
    let kind: MediaKind?
    let shelf: ProfileShelf
}
