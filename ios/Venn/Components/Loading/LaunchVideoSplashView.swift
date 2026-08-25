import SwiftUI

/// Full-screen brand splash shown once at app startup.
///
/// Just the mark, held for a beat. There was a launch video here on both
/// platforms; it did not look good and has been dropped, and what is left
/// is the still mark that used to be the Reduce Motion fallback. A launch
/// state still earns its place — the app has work to do before it can show
/// anything — but it does not need a film to do it.
struct LaunchVideoSplashView: View {
    private static let holdDuration: Duration = .seconds(1.0)

    var onCompletion: (@MainActor () -> Void)?

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        let variant: AppThemeVariant = colorScheme == .dark ? .dark : .light

        ZStack {
            variant.backgroundColor
                .ignoresSafeArea()

            StaticLaunchMark(color: variant.markColor)
                .task {
                    try? await Task.sleep(for: Self.holdDuration)
                    guard !Task.isCancelled else { return }
                    onCompletion?()
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Venn loading")
        .accessibilityIdentifier("launch_video_splash")
    }
}

struct StaticLaunchMark: View {
    let color: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(color)
                .frame(width: 132, height: 78)
                .offset(y: -64)
            Ellipse()
                .fill(color)
                .frame(width: 78, height: 132)
                .rotationEffect(.degrees(-18))
                .offset(x: -54, y: 26)
            Ellipse()
                .fill(color)
                .frame(width: 78, height: 132)
                .rotationEffect(.degrees(18))
                .offset(x: 54, y: 26)
        }
        .frame(width: 220, height: 220)
        .accessibilityHidden(true)
    }
}

#Preview {
    LaunchVideoSplashView()
}
