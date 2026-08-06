import SwiftUI

/// One line of activity: who, what, when. Mirrors web's
/// `NotificationRow.tsx` in copy and layout (CLAUDE.md rule 17).
///
/// Unread rows carry a tinted background rather than a dot, because the
/// whole list is marked read the moment the screen appears — a per-row dot
/// would be stale before anyone looked at it. The tint is the record of
/// what arrived since last time.
struct NotificationRowView: View {
    let notification: AppNotification

    private var actorName: String {
        notification.actor.displayName ?? notification.actor.username
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            AvatarBadge(
                name: actorName,
                avatarURL: notification.actor.avatarURL,
                size: 36
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("\(Text(actorName).bold()) \(notification.summary)")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let body = notification.commentBody, !body.isEmpty {
                    Text(verbatim: "“\(body)”")
                        .font(Theme.Font.footnote)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            Text(RelativeTime.short(from: notification.createdAt))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.lg)
        .background(notification.isUnread ? Theme.Color.surfaceStrong : .clear)
    }
}

#Preview {
    let actor = UserProfile(
        id: UUID(),
        username: "maya",
        displayName: "Maya Chen",
        avatarURL: nil,
        bio: nil,
        createdAt: .now
    )

    return VStack(spacing: 0) {
        NotificationRowView(notification: AppNotification(
            id: UUID(),
            kind: .like,
            actor: actor,
            createdAt: .now.addingTimeInterval(-600),
            readAt: nil,
            postID: UUID(),
            postTitle: "Past Lives",
            commentBody: nil
        ))
        NotificationRowView(notification: AppNotification(
            id: UUID(),
            kind: .comment,
            actor: actor,
            createdAt: .now.addingTimeInterval(-7200),
            readAt: .now,
            postID: UUID(),
            postTitle: "Piranesi",
            commentBody: "Loved this one."
        ))
        NotificationRowView(notification: AppNotification(
            id: UUID(),
            kind: .followRequest,
            actor: actor,
            createdAt: .now.addingTimeInterval(-86400),
            readAt: .now,
            postID: nil,
            postTitle: nil,
            commentBody: nil
        ))
    }
}
