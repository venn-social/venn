import Foundation
import Observation

/// Typed access to environment-supplied configuration.
///
/// At build time, the pre-build script reads `.env` and writes the values into
/// `Resources/GeneratedConfig.xcconfig`, which the Xcode project includes. The
/// values flow through `Info.plist` substitution and are read here at launch.
///
/// Use this type instead of reading `Bundle.main.infoDictionary` directly so
/// that screens depend on a typed surface rather than untyped string lookups.
@Observable
final class AppConfig {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let appEnv: AppEnv
    let sentryDSN: String?
    let postHogAPIKey: String?
    let postHogHost: URL

    enum AppEnv: String {
        case development
        case staging
        case production
    }

    init(
        supabaseURL: URL,
        supabaseAnonKey: String,
        appEnv: AppEnv,
        sentryDSN: String?,
        postHogAPIKey: String?,
        postHogHost: URL
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.appEnv = appEnv
        self.sentryDSN = sentryDSN
        self.postHogAPIKey = postHogAPIKey
        self.postHogHost = postHogHost
    }

    /// Read configuration from the app's `Info.plist`. Crashes early if a
    /// required key is missing, since the app cannot function without
    /// Supabase credentials.
    static func load() -> AppConfig {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let urlString = info["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = info["SUPABASE_ANON_KEY"] as? String,
              !anonKey.isEmpty
        else {
            preconditionFailure(
                "Missing SUPABASE_URL or SUPABASE_ANON_KEY. Copy .env.example to .env and fill in real values."
            )
        }

        let envString = (info["APP_ENV"] as? String) ?? "development"
        let env = AppEnv(rawValue: envString) ?? .development

        let sentryDSN = (info["SENTRY_DSN"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let postHogKey = (info["POSTHOG_API_KEY"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let postHogHostString = (info["POSTHOG_HOST"] as? String) ?? "https://us.i.posthog.com"
        let postHogHost = URL(string: postHogHostString) ?? URL(staticString: "https://us.i.posthog.com")

        return AppConfig(
            supabaseURL: url,
            supabaseAnonKey: anonKey,
            appEnv: env,
            sentryDSN: sentryDSN,
            postHogAPIKey: postHogKey,
            postHogHost: postHogHost
        )
    }

    /// Stub for SwiftUI previews and tests.
    static let preview = AppConfig(
        supabaseURL: URL(staticString: "https://preview.supabase.co"),
        supabaseAnonKey: "preview",
        appEnv: .development,
        sentryDSN: nil,
        postHogAPIKey: nil,
        postHogHost: URL(staticString: "https://us.i.posthog.com")
    )
}
