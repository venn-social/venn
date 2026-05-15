import SwiftUI

/// Centered loading indicator with an optional caption. Use for full-screen
/// loading states (session restoration, initial fetch). For inline loading
/// inside a button, prefer `PrimaryButton`'s `isLoading` flag.
struct LoadingView: View {
    let caption: LocalizedStringKey?

    @Environment(AppearanceSettings.self)
    private var appearanceSettings
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorScheme)
    private var colorScheme

    init(caption: LocalizedStringKey? = nil) {
        self.caption = caption
    }

    var body: some View {
        let variant = appearanceSettings.mode.resolvedVariant(systemColorScheme: colorScheme)

        ZStack {
            variant.backgroundColor
                .ignoresSafeArea()

            if reduceMotion {
                StaticLaunchMark(color: variant.markColor)
            } else {
                VennVideoPlayer(
                    resource: variant.loadingVideo,
                    loops: true,
                    backgroundColor: variant.uiBackgroundColor
                )
                .id(variant.loadingVideo.name)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }

            captionView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("loading_view")
    }

    @ViewBuilder private var captionView: some View {
        if let caption {
            VStack {
                Spacer()
                Text(caption)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, Theme.Spacing.xxxl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

#Preview("plain") {
    LoadingView()
        .environment(AppearanceSettings())
}

#Preview("with caption") {
    LoadingView(caption: "Loading your feed…")
        .environment(AppearanceSettings())
}
