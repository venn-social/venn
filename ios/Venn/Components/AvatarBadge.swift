import SwiftUI

/// Minimal circular avatar fallback used anywhere a profile image is missing.
struct AvatarBadge: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Theme.Color.graphite)
            .frame(width: size, height: size)
            .overlay {
                Text(initial)
                    .font(font)
                    .foregroundStyle(Theme.Color.onAccent)
            }
            .accessibilityLabel(Text(name))
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? "?"
    }

    private var font: Font {
        size >= 64 ? Theme.Font.title2.weight(.semibold) : Theme.Font.headline
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        AvatarBadge(name: "Maya Chen")
        AvatarBadge(name: "Maya Chen", size: 74)
    }
    .padding(Theme.Spacing.xl)
}
