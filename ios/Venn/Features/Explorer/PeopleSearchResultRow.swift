import SwiftUI

/// A single profile in the Explorer People search results. Same surface
/// shape as `ExplorerSearchResultRow`; tapping pushes the public profile
/// via the enclosing `NavigationLink`.
struct PeopleSearchResultRow: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarBadge(name: profile.displayName ?? profile.username)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: profile.displayName ?? profile.username)
                    .font(Theme.Font.body.weight(.medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(1)
                Text(verbatim: "@\(profile.username)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
    }
}

#Preview {
    VStack(spacing: 8) {
        PeopleSearchResultRow(profile: UserProfile(
            id: UUID(),
            username: "maya",
            displayName: "Maya Chen",
            avatarURL: nil,
            bio: nil,
            createdAt: Date()
        ))
        PeopleSearchResultRow(profile: UserProfile(
            id: UUID(),
            username: "ada_lovelace",
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            createdAt: Date()
        ))
    }
    .padding()
}
