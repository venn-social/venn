import SwiftUI

/// Full-screen list of pending follow requests for the signed-in user's
/// own account, with inline accept/reject. Reached from a "Requests" icon
/// button on `ProfileView`'s top bar — only shown there when the account
/// is private, since a public account never has pending requests
/// (`request_follow` auto-accepts).
struct FollowRequestsView: View {
    @State var viewModel: FollowRequestsViewModel

    var body: some View {
        Screen {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading requests…")
            case let .loaded(requests):
                if requests.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(requests) { requester in
                                requestRow(requester)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.lg)
                    }
                    .scrollContentBackground(.hidden)
                }
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load requests") {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle("Follow Requests")
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
        }
        .task { await viewModel.load() }
    }

    private func requestRow(_ requester: UserProfile) -> some View {
        let isResponding = viewModel.respondingTo.contains(requester.id)
        return HStack(spacing: Theme.Spacing.md) {
            AvatarBadge(name: requester.displayName ?? requester.username, avatarURL: requester.avatarURL)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: requester.displayName ?? requester.username)
                    .font(Theme.Font.body.weight(.medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)
                Text(verbatim: "@\(requester.username)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.sm) {
                responseButton(systemImage: "xmark", accessibilityLabel: "Decline") {
                    Task { await viewModel.respond(to: requester, accept: false) }
                }
                responseButton(
                    systemImage: "checkmark",
                    accessibilityLabel: "Accept",
                    tint: Theme.Color.accent
                ) {
                    Task { await viewModel.respond(to: requester, accept: true) }
                }
            }
            .opacity(isResponding ? 0.4 : 1)
            .disabled(isResponding)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
    }

    private func responseButton(
        systemImage: String,
        accessibilityLabel: String,
        tint: Color = Theme.Color.textSecondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.Font.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Theme.Color.surfaceStrong, in: .circle)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var emptyView: some View {
        EmptyStateView(
            systemImage: "person.crop.circle.badge.checkmark",
            title: "No pending requests",
            message: "Requests to follow your private account will show up here."
        )
    }
}

#Preview {
    NavigationStack {
        FollowRequestsView(viewModel: FollowRequestsViewModel(
            userID: UUID(),
            service: PreviewFollowService()
        ))
    }
}

private struct PreviewFollowService: FollowServicing {
    func followStatus(followerID _: UUID, followeeID _: UUID) async throws -> FollowStatus? {
        nil
    }

    func requestFollow(followerID _: UUID, followeeID _: UUID) async throws -> FollowStatus {
        .accepted
    }

    func unfollow(followerID _: UUID, followeeID _: UUID) async throws {}
    func respondToRequest(followerID _: UUID, followeeID _: UUID, accept _: Bool) async throws {}
    func followers(of _: UUID, limit _: Int) async throws -> [UserProfile] {
        []
    }

    func following(of _: UUID, limit _: Int) async throws -> [UserProfile] {
        []
    }

    func pendingRequests(for _: UUID, limit _: Int) async throws -> [UserProfile] {
        [
            UserProfile(
                id: UUID(),
                username: "ada",
                displayName: "Ada Lovelace",
                avatarURL: nil,
                bio: nil,
                createdAt: Date()
            ),
        ]
    }
}
