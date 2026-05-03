import SwiftUI

@main
struct VennApp: App {
    @State private var appConfig = AppConfig.load()

    init() {
        Observability.bootstrap(config: AppConfig.load())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appConfig)
                .environment(SupabaseClientProvider.shared)
        }
    }
}
