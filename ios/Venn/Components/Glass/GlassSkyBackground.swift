import SwiftUI

/// App-wide background. Renders a cool atmospheric gradient — "morning sky
/// on glass" in light mode, "night sky" in dark — edge-to-edge under all
/// content. Liquid Glass surfaces (tab bar, nav bar, glass cards)
/// naturally refract this gradient, giving the app its
/// "glass-floating-over-sky" feel.
///
/// Mounted at the very base of `RootView`'s ZStack so it sits beneath
/// everything, including the splash and the system chrome (tab bar, nav
/// bar). Screens inside the app are transparent containers; their
/// content sits on top of this gradient.
///
/// Honors **Reduce Transparency** by collapsing to `Theme.Color.skySolid`
/// — users with the accessibility setting on get a coherent solid surface
/// that matches the gradient's mid-tone. Honors safe-area by ignoring it
/// (gradient extends edge-to-edge).
struct GlassSkyBackground: View {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                Theme.Color.skySolid
            } else {
                Theme.Gradient.sky
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview("light") {
    GlassSkyBackground()
        .preferredColorScheme(.light)
}

#Preview("dark") {
    GlassSkyBackground()
        .preferredColorScheme(.dark)
}
