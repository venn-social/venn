import Testing
@testable import Venn

struct AppConfigTests {
    @Test func previewConfigHasUsableDefaults() {
        let config = AppConfig.preview
        #expect(config.appEnv == .development)
        #expect(!config.supabaseAnonKey.isEmpty)
        #expect(config.sentryDSN == nil)
    }
}
