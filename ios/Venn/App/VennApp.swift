import SwiftUI

@main
struct VennApp: App {
    @State private var appConfig: AppConfig
    @State private var clientProvider: SupabaseClientProvider
    @State private var authState: AuthState
    @State private var languageStore = LanguageStore()
    @State private var scrollState: ScrollState
    private let authService: AuthService

    init() {
        // Cover art (TMDB / OpenLibrary / Cover Art Archive) rides
        // AsyncImage + the shared URLCache, and iOS's default cache is far
        // too small for an image-forward feed — covers re-download on every
        // scroll-back. Size it once at boot (docs/TECH_DEBT.md item 4).
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )

        let config = AppConfig.load()
        let provider = SupabaseClientProvider.shared
        let service = AuthService(client: provider.client)

        Observability.bootstrap(config: config)

        _appConfig = State(initialValue: config)
        _clientProvider = State(initialValue: provider)
        _authState = State(initialValue: AuthState(service: service))
        _scrollState = State(initialValue: ScrollState())
        authService = service
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appConfig)
                .environment(clientProvider)
                .environment(authState)
                .environment(scrollState)
                .environment(languageStore)
                .task { await authState.bootstrap() }
                .onOpenURL { url in
                    Task { try? await authService.handleCallback(url) }
                }
        }
    }
}
