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
    /// Cap on how far the gradient drifts during scroll, in points. Small
    /// — a few pixels of motion is enough to add depth without becoming
    /// the focal point.
    private static let parallaxLimit: CGFloat = 12

    /// Multiplier applied to the active scroll view's content offset.
    /// `0.05` means a 240-point scroll produces the full 12-point drift,
    /// after which the offset saturates. Tuned to feel like atmospheric
    /// haze, not a parallax billboard.
    private static let parallaxFactor: CGFloat = 0.05

    @Environment(ScrollState.self)
    private var scrollState: ScrollState?
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        // Render the gradient slightly larger than the container and
        // pre-offset it so the parallax shift never reveals an edge gap.
        GeometryReader { geo in
            content
                .frame(
                    width: geo.size.width,
                    height: geo.size.height + Self.parallaxLimit * 2
                )
                .offset(y: parallaxOffset - Self.parallaxLimit)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        if reduceTransparency {
            Theme.Color.skySolid
        } else {
            Theme.Gradient.sky
        }
    }

    private var parallaxOffset: CGFloat {
        guard !reduceMotion, let scrollState else { return 0 }
        let raw = -scrollState.offset * Self.parallaxFactor
        return max(min(raw, Self.parallaxLimit), -Self.parallaxLimit)
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
