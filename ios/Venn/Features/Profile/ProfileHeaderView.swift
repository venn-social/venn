import SwiftUI

/// Identity block at the top of the profile: avatar, name, handle, and bio,
/// with an optional inline Edit affordance. Borderless and minimal to match
/// the refreshed design.
struct ProfileHeaderView: View {
    let name: String
    let handle: String
    let bio: String?
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                AvatarBadge(name: name, size: 66)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(verbatim: name)
                        .font(Theme.Font.title2)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(verbatim: "@\(handle)")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                if let onEdit {
                    Button("Edit", action: onEdit)
                        .font(Theme.Font.callout.weight(.semibold))
                        .foregroundStyle(Theme.Color.accent)
                        .accessibilityIdentifier("profile_edit_button")
                }
            }

            if let bio, !bio.isEmpty {
                Text(verbatim: bio)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ProfileHeaderView(
        name: "Maya Chen",
        handle: "maya",
        bio: "movies that linger, loud dinners, albums with one perfect skip"
    ) {}
        .padding(Theme.Spacing.lg)
}
