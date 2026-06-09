import SwiftUI

/// Identity block at the top of the profile: avatar with the name and handle
/// beside it, and follower / following counts beneath. Borderless and minimal.
struct ProfileHeaderView: View {
    let name: String
    let handle: String
    let followers: Int
    let following: Int

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            AvatarBadge(name: name, size: 72)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: name)
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(verbatim: "@\(handle)")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)

                HStack(spacing: Theme.Spacing.lg) {
                    FollowStat(value: followers, label: "Followers")
                    FollowStat(value: following, label: "Following")
                }
                .padding(.top, Theme.Spacing.xs)
            }

            Spacer(minLength: 0)
        }
    }
}

/// A single "<count> <label>" follow statistic.
private struct FollowStat: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("\(value)")
                .font(Theme.Font.callout.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}

#Preview {
    ProfileHeaderView(name: "Maya Chen", handle: "maya", followers: 128, following: 86)
        .padding(Theme.Spacing.lg)
}
