import SwiftUI

/// Profile tab. Loads the signed-in user's profile from Supabase and renders
/// the identity header, follow counts, primary actions, and a Collection /
/// Watchlist cover gallery. Share + settings live in a top bar; both, like
/// the Add and Edit buttons, are wired in a later pass.
struct ProfileView: View {
    @Environment(AuthState.self)
    private var authState
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: ProfileViewModel?
    @State private var editViewModel: ProfileEditViewModel?
    @State private var shelf: ProfileShelf = .collection

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .sheet(
                    isPresented: Binding(
                        get: { editViewModel != nil },
                        set: { if !$0 { editViewModel = nil } }
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
                errorView(reason: reason) { Task { await viewModel.load() } }
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
                        followers: snapshot.followCounts.followers,
                        following: snapshot.followCounts.following
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
        let items = shelf == .collection ? snapshot.collection : snapshot.watchlist
        return Group {
            if items.isEmpty {
                Text(shelf == .collection ? "Nothing in your collection yet." : "Your watchlist is empty.")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.md)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3),
                    spacing: Theme.Spacing.sm
                ) {
                    ForEach(items) { media in
                        MediaCoverTile(
                            title: media.title,
                            kind: media.kind,
                            height: 150,
                            cornerRadius: Theme.Radius.md
                        )
                    }
                }
            }
        }
    }

    private func errorView(
        reason: ProfileViewModel.ErrorReason,
        retry: @escaping () -> Void
    ) -> some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: errorTitle(for: reason),
            message: errorMessage(for: reason),
            actionTitle: "Try again",
            action: retry
        )
    }

    private func errorTitle(for reason: ProfileViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .offline: "You're offline"
        case .unknown: "Couldn't load your profile"
        }
    }

    private func errorMessage(for reason: ProfileViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .offline: "Check your connection and try again."
        case .unknown: "Something went wrong. Please try again."
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

/// Collection / Watchlist text tabs above the cover gallery.
private struct ShelfTabs: View {
    @Binding var selection: ProfileShelf

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            ForEach(ProfileShelf.allCases) { shelf in
                let isSelected = shelf == selection
                Button {
                    selection = shelf
                } label: {
                    Text(shelf.title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                }
            }
            Spacer()
        }
    }
}
