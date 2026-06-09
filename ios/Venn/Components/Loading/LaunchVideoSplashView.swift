import SwiftUI

/// Full-screen brand splash shown once at app startup.
///
/// `onCompletion` fires when the launch video finishes playing, or after a
/// short hold for Reduce Motion users (who see `StaticLaunchMark` instead of
/// the video). Owners drive splash dismissal off this callback rather than a
/// hardcoded timer so the brand intro always plays to its natural end.
struct LaunchVideoSplashView: View {
    private static let reduceMotionHoldDuration: Duration = .seconds(1.5)

    var onCompletion: (@MainActor () -> Void)?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        let variant: AppThemeVariant = colorScheme == .dark ? .dark : .light

        ZStack {
            variant.backgroundColor
                .ignoresSafeArea()

            if reduceMotion {
                StaticLaunchMark(color: variant.markColor)
                    .task {
                        try? await Task.sleep(for: Self.reduceMotionHoldDuration)
                        guard !Task.isCancelled else { return }
                        onCompletion?()
                    }
            } else {
                VennVideoPlayer(
                    resource: variant.launchVideo,
                    backgroundColor: variant.uiBackgroundColor,
                    onCompletion: onCompletion
                )
                .id(variant.launchVideo.name)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
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
