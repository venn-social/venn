import SwiftUI

/// Identity block at the top of the profile: avatar with the name and handle
/// beside it, and follower / following counts beneath. Borderless and minimal.
/// Pass the tap closures to make the counts navigate to the follow lists;
/// leave them nil for a static header.
struct ProfileHeaderView: View {
    let name: String
    let handle: String
    var avatarURL: URL?
    let followers: Int
    let following: Int
    var onTapFollowers: (() -> Void)?
    var onTapFollowing: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            AvatarBadge(name: name, avatarURL: avatarURL, size: 72)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: name)
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(verbatim: "@\(handle)")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)

                HStack(spacing: Theme.Spacing.lg) {
                    FollowStat(value: followers, label: "Followers", onTap: onTapFollowers)
                    FollowStat(value: following, label: "Following", onTap: onTapFollowing)
                }
                .padding(.top, Theme.Spacing.xs)
            }

            Spacer(minLength: 0)
        }
    }
}

/// A single "<count> <label>" follow statistic, tappable when `onTap` is set.
private struct FollowStat: View {
    let value: Int
    let label: LocalizedStringKey
    var onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("\(value)")
                .font(Theme.Font.footnote.weight(.medium))
                .foregroundStyle(Theme.Color.textSecondary)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}

#Preview {
    ProfileHeaderView(name: "Maya Chen", handle: "maya", followers: 128, following: 86)
        .padding(Theme.Spacing.lg)
}
