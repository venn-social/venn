import SwiftUI

struct ContentView: View {
    @Environment(AppConfig.self)
    private var config

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("venn")
                .font(.largeTitle.weight(.semibold))
            Text(config.appEnv.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environment(AppConfig.preview)
}
