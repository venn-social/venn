import Foundation
import Observation
import Supabase

/// Single shared Supabase client. Inject via `.environment(...)` rather than
/// reading `.shared` directly from views — this lets tests substitute a stub.
///
/// Service wrappers in `Services/*.service.swift` should be the only things
/// calling this client. Views and view-models call services, services call
/// this provider.
@Observable
final class SupabaseClientProvider: @unchecked Sendable {
    /// @unchecked Sendable: `client` is `let` and SupabaseClient is itself
    /// Sendable, so instances are safe to share across threads. Swift cannot
    /// infer Sendable from @Observable on its own.
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    static let shared: SupabaseClientProvider = {
        let config = AppConfig.load()
        let client = SupabaseClient(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.supabaseAnonKey
        )
        return SupabaseClientProvider(client: client)
    }()

    // periphery:ignore - reachable only from the #Preview macro, which
    // periphery cannot statically resolve.
    /// Used in SwiftUI previews. Points at preview values; never makes a real
    /// network call in a preview because the URL is not real.
    static let preview: SupabaseClientProvider = {
        let client = SupabaseClient(
            supabaseURL: AppConfig.preview.supabaseURL,
            supabaseKey: AppConfig.preview.supabaseAnonKey
        )
        return SupabaseClientProvider(client: client)
    }()
}
