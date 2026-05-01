import Foundation
import PostHog
import Sentry

/// One-shot bootstrapper for crash reporting + product analytics. Called once
/// from `VennApp.init`. Both SDKs no-op when their key/DSN is unset, so this
/// is safe to call in development without any config.
enum Observability {
    static func bootstrap(config: AppConfig) {
        if let dsn = config.sentryDSN {
            SentrySDK.start { options in
                options.dsn = dsn
                options.environment = config.appEnv.rawValue
                options.tracesSampleRate = config.appEnv == .production ? 0.2 : 1.0
                options.profilesSampleRate = config.appEnv == .production ? 0.1 : 1.0
            }
        }

        if let apiKey = config.postHogAPIKey {
            let phConfig = PostHogConfig(apiKey: apiKey, host: config.postHogHost.absoluteString)
            phConfig.captureApplicationLifecycleEvents = true
            phConfig.captureScreenViews = true
            PostHogSDK.shared.setup(phConfig)
        }
    }
}
