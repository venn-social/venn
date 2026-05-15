import SwiftUI

/// Full-screen brand splash shown once at app startup.
struct LaunchVideoSplashView: View {
    @Environment(AppearanceSettings.self)
    private var appearanceSettings
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        let variant = appearanceSettings.mode.resolvedVariant(systemColorScheme: colorScheme)

        ZStack {
            variant.backgroundColor
                .ignoresSafeArea()

            if reduceMotion {
                StaticLaunchMark(color: variant.markColor)
            } else {
                VennVideoPlayer(
                    resource: variant.launchVideo,
                    backgroundColor: variant.uiBackgroundColor
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
        .environment(AppearanceSettings())
}
