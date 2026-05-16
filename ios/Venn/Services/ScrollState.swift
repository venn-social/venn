import Foundation

/// App-wide observable scroll offset. The currently-visible `ScrollView`
/// publishes its vertical content offset here (via
/// `.onScrollGeometryChange`), and `GlassSkyBackground` reads it to drift
/// the atmospheric gradient as the user scrolls — the "glass-floating-
/// over-sky" effect gets meaningful depth this way without any per-screen
/// boilerplate beyond a single modifier call.
///
/// One shared instance injected at `VennApp` and read via
/// `@Environment(ScrollState.self)`. Different tabs overwrite this on each
/// scroll, which is exactly the behaviour we want: only the visible
/// scroll view's offset matters; the other tabs are off-screen.
@Observable
@MainActor
final class ScrollState {
    /// Vertical offset of the currently-visible scroll view, in points.
    /// 0 at rest, positive when content has been scrolled up (i.e. user
    /// has dragged content up to read more).
    var offset: CGFloat = 0
}
