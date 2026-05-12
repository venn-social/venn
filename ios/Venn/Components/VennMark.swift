import SwiftUI

/// Small reusable brand mark built from the overlap primitive itself. It uses
/// three translucent circles so the center lens is always the strongest point.
struct VennMark: View {
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Color.graphite.opacity(0.88))
                .frame(width: size * 0.58, height: size * 0.58)
                .offset(x: -size * 0.16, y: -size * 0.12)
            Circle()
                .fill(Theme.Color.graphite.opacity(0.42))
                .frame(width: size * 0.58, height: size * 0.58)
                .offset(x: size * 0.16, y: -size * 0.12)
            Circle()
                .fill(Theme.Color.graphite.opacity(0.68))
                .frame(width: size * 0.58, height: size * 0.58)
                .offset(y: size * 0.18)
        }
        .compositingGroup()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    VennMark()
        .padding(Theme.Spacing.xl)
        .background(Theme.Color.paper)
}
