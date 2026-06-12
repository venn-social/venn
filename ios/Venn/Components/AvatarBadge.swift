import SwiftUI

/// Circular avatar. Renders the profile photo when `avatarURL` is set,
/// fading in over the initial-on-graphite fallback (which doubles as the
/// loading and no-photo state).
struct AvatarBadge: View {
    let name: String
    var avatarURL: URL?
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
            .overlay {
                if let avatarURL {
                    AsyncImage(
                        url: avatarURL,
                        transaction: Transaction(animation: .easeIn(duration: 0.2))
                    ) { phase in
                        if case let .success(image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                                .transition(.opacity)
                        }
                    }
                }
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
