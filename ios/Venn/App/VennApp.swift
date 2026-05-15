import SwiftUI

@main
struct VennApp: App {
    @State private var appConfig: AppConfig
    @State private var clientProvider: SupabaseClientProvider
    @State private var authState: AuthState
    @State private var appearanceSettings: AppearanceSettings
    private let authService: AuthService

    init() {
        let config = AppConfig.load()
        let provider = SupabaseClientProvider.shared
        let service = AuthService(client: provider.client)

        Observability.bootstrap(config: config)

        _appConfig = State(initialValue: config)
        _clientProvider = State(initialValue: provider)
        _authState = State(initialValue: AuthState(service: service))
        _appearanceSettings = State(initialValue: AppearanceSettings())
        authService = service
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appConfig)
                .environment(clientProvider)
                .environment(authState)
                .environment(appearanceSettings)
                .preferredColorScheme(appearanceSettings.mode.preferredColorScheme)
                .task { await authState.bootstrap() }
                .onOpenURL { url in
                    Task { try? await authService.handleCallback(url) }
                }
        }
    }
}
