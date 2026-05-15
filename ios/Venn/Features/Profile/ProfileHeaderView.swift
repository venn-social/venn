import SwiftUI

struct ProfileHeaderView: View {
    let name: String
    let handle: String
    let bio: String?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            AvatarBadge(name: name, size: 74)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(verbatim: name)
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)

                Text(verbatim: "@\(handle)")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)

                if let bio, !bio.isEmpty {
                    Text(verbatim: bio)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 1.5)
        }
    }
}

#Preview {
    ProfileHeaderView(
        name: "Maya Chen",
        handle: "maya",
        bio: "movies that linger, loud dinners, albums with one perfect skip"
    )
    .padding(Theme.Spacing.lg)
}
