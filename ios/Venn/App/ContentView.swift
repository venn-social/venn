import SwiftUI

struct ContentView: View {
    @Environment(AppConfig.self)
    private var config

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Color.accent)
            Text("venn")
                .font(Theme.Font.largeTitle)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(config.appEnv.rawValue)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
    }
}

#Preview {
    ContentView()
        .environment(AppConfig.preview)
}
