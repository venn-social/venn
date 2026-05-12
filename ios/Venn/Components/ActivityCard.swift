import SwiftUI

/// Social feed row for a friend's activity around a piece of content.
struct ActivityCard: View {
    let name: String
    let action: String
    let title: String
    let detail: String
    let rating: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                AvatarBadge(name: name)

                Text("\(name) \(action)")
                    .font(Theme.Font.callout.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)

                Spacer()

                if let rating {
                    Text(rating)
                        .font(Theme.Font.caption.weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Color.surfaceStrong, in: .capsule)
                }
            }

            Text(title)
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            Text(detail)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 0.5)
        }
    }
}

#Preview {
    ActivityCard(
        name: "Maya",
        action: "logged",
        title: "Past Lives",
        detail: "quiet, devastating, exactly the right kind of Sunday movie",
        rating: "4.5"
    )
    .padding(Theme.Spacing.lg)
}
