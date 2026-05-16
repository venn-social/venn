import SwiftUI

#if DEBUG
    struct DesignPreviewView: View {
        @State private var selection = initialSelection

        var body: some View {
            TabView(selection: $selection) {
                Tab("Feed", systemImage: "square.stack.3d.up", value: MainTab.feed) {
                    FeedView()
                }
                Tab("Explorer", systemImage: "sparkle.magnifyingglass", value: MainTab.explorer) {
                    ExplorerView()
                }
                Tab("Profile", systemImage: "person.crop.circle", value: MainTab.profile) {
                    ProfilePrototypeView()
                }
            }
            .tint(Theme.Color.accent)
            .vennTabFeedback(trigger: selection)
            .swipeBetweenTabs(selection: $selection)
        }

        private static var initialSelection: MainTab {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-previewExplorer") {
                return .explorer
            }
            if arguments.contains("-previewProfile") {
                return .profile
            }
            return .feed
        }
    }

    #Preview {
        DesignPreviewView()
            .environment(AppearanceSettings())
    }
#endif
