import SwiftUI

/// Read-only profile for another user, pushed from the Explorer People
/// search. Reuses the signed-in profile's building blocks (header, shelf
/// tabs, cover gallery) via the shared `ProfileViewModel` — minus the owner
/// affordances (edit, add, settings) and shelf tap-through. Follow button
/// and the Venn overlap land here with the follow system.
struct PublicProfileView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    /// The search result that was tapped. Drives the navigation title
    /// immediately; the full snapshot (counts + shelves) loads async.
    let profile: UserProfile

    @State private var viewModel: ProfileViewModel?
    @State private var shelf: ProfileShelf = .collection

    var body: some View {
        Screen {
            content
        }
        .navigationTitle("@\(profile.username)")
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
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
                    following: snapshot.followCounts.following
                )
                if let bio = snapshot.profile.bio {
                    Text(verbatim: bio)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
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

    private func ensureLoaded() async {
        if viewModel == nil {
            let viewModel = ProfileViewModel(
                userID: profile.id,
                service: ProfileService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load()
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
}
