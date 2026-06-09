#if DEBUG
    import SwiftUI

    /// Navigable shell for venn's visual style preview — the three primary
    /// tabs rendered in the refreshed design language over the app's glass-sky
    /// background, with an icon-only Liquid Glass tab bar.
    ///
    /// DEBUG-only, reachable via the `-previewStyle` launch argument (see
    /// `RootView`). Uses sample data only — no production service is touched.
    /// This is a design reference; the production tabs adopt the language in a
    /// later restyle.
    struct StylePreviewShell: View {
        @State private var selection = Self.initialSelection

        var body: some View {
            TabView(selection: $selection) {
                Tab(value: 0) { FeedPreviewPage() } label: { Image(systemName: "square.stack") }
                Tab(value: 1) { ExplorePreviewPage() } label: { Image(systemName: "sparkle.magnifyingglass") }
                Tab(value: 2) { ProfilePreviewPage() } label: { Image(systemName: "person.crop.circle") }
            }
            .tint(StyleToken.accent)
        }

        /// Lets screenshot tooling open a specific tab via launch argument
        /// (`-previewStyleTab explore` / `-previewStyleTab profile`).
        private static var initialSelection: Int {
            let args = ProcessInfo.processInfo.arguments
            guard let index = args.firstIndex(of: "-previewStyleTab"), index + 1 < args.count else {
                return 0
            }
            switch args[index + 1] {
            case "explore": return 1
            case "profile": return 2
            default: return 0
            }
        }
    }

    #Preview("light") {
        ZStack { GlassSkyBackground()
            StylePreviewShell()
        }
        .preferredColorScheme(.light)
    }

    #Preview("dark") {
        ZStack { GlassSkyBackground()
            StylePreviewShell()
        }
        .preferredColorScheme(.dark)
    }
#endif
