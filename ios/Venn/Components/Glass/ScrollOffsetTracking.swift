import SwiftUI

extension View {
    /// Reports the receiving scroll view's vertical content offset to the
    /// shared `ScrollState` so `GlassSkyBackground` can apply parallax to
    /// the atmospheric gradient. Attach to every top-level `ScrollView`
    /// rendered inside a tab.
    ///
    /// No-op if no `ScrollState` is in the environment (e.g. during
    /// SwiftUI previews), so screens stay preview-safe.
    func tracksGlassSkyParallax() -> some View {
        modifier(GlassSkyParallaxTrackerModifier())
    }
}

private struct GlassSkyParallaxTrackerModifier: ViewModifier {
    @Environment(ScrollState.self)
    private var scrollState: ScrollState?

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollState?.offset = newValue
        }
    }
}
