import SwiftUI

/// Where a notification row leads. A like or comment opens the post; a
/// follow opens the person who did it.
enum NotificationDestination: Hashable {
    case post(UUID)
    case profile(UserProfile)

    init(_ notification: AppNotification) {
        if let postID = notification.postID {
            self = .post(postID)
        } else {
            self = .profile(notification.actor)
        }
    }
}

/// Activity tab: likes, comments, follows, and follow requests. Mirrors
/// web's `/notifications` in copy and ordering (CLAUDE.md rule 17).
///
/// Until this existed the social loop only ran one way — you could like
/// someone's post and they would never find out unless they happened to
/// open it again.
struct NotificationsView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    /// Owned by the shell so the badge survives tab switches; the screen
    /// itself only reads and refreshes it.
    let viewModel: NotificationsViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Activity")
                .containerBackground(for: .navigation) {
                    GlassSkyBackground()
                }
                .navigationDestination(for: NotificationDestination.self) { destination in
                    switch destination {
                    case let .post(postID):
                        PostPermalinkView(postID: postID)
                    case let .profile(profile):
                        PublicProfileView(profile: profile)
                    }
                }
                .navigationDestination(for: Media.self) { media in
                    MediaDetailView(media: media)
                }
        }
        .task {
            if case .loading = viewModel.state {
                await viewModel.load()
            }
            // Clearing on appearance, not on scroll: the list is short and
            // shown all at once, so anything narrower would leave the badge
            // claiming there is still something to see.
            await viewModel.markAllRead()
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            DeferredLoadingView(caption: "Loading your activity…")
        case let .loaded(notifications):
            if notifications.isEmpty {
                emptyView
            } else {
                list(notifications)
            }
        case let .error(reason):
            Screen {
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load your activity") {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    private func list(_ notifications: [AppNotification]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notifications) { notification in
                    NavigationLink(value: NotificationDestination(notification)) {
                        NotificationRowView(notification: notification)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    private var emptyView: some View {
        Screen {
            EmptyStateView(
                systemImage: "bell",
                title: "Nothing yet",
                message: "Likes, comments, and new followers show up here."
            )
        }
    }
}
