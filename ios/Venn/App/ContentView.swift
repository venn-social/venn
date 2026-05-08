import SwiftUI

struct ContentView: View {
    @Environment(AppConfig.self)
    private var config

    var body: some View {
        Screen {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Color.accent)
                Text(verbatim: "venn")
                    .font(Theme.Font.largeTitle)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(verbatim: config.appEnv.rawValue)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppConfig.preview)
}
