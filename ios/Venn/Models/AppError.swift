import Foundation
import Supabase

/// Semantic, `Sendable` error type that every `<Feature>Service` method
/// throws (eventually — services adopt this incrementally). View-models
/// catch `AppError` and translate it into their own
/// `State.error(Reason)` for the view layer to render. See
/// `docs/decisions/0006-error-handling-layering.md`.
///
/// The `unknown` case stores a `String` (not the underlying `Error`) so
/// the type stays `Sendable` under strict concurrency. The original
/// description is captured at the boundary via `localizedDescription`.
enum AppError: Error, Equatable {
    /// Connectivity, timeout, DNS — anything `URLError`-shaped.
    case network

    /// 401, missing/expired session, RLS denial.
    case unauthorized

    /// 4xx where the server returned a message we should surface to the user
    /// (validation, conflict, etc.).
    case validation(String)

    /// 429.
    case rateLimited

    /// 5xx.
    case server

    /// Anything that didn't match a more specific case. Carries a string
    /// rather than the original `Error` so `AppError` is `Sendable`.
    case unknown(message: String)
}

extension AppError {
    /// Single mapping site for every third-party error shape the app
    /// might see. Adding a new mapping (e.g. a fresh PostgREST code or
    /// auth case we want to surface differently) is a one-line change
    /// here — call sites don't change.
    static func from(_ error: any Error) -> AppError {
        if let app = error as? AppError {
            return app
        }
        if let url = error as? URLError {
            return mapURLError(url)
        }
        if let auth = error as? AuthError {
            return mapAuthError(auth)
        }
        if let postgrest = error as? PostgrestError {
            return mapPostgrestError(postgrest)
        }
        return .unknown(message: error.localizedDescription)
    }

    private static func mapURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            .network
        default:
            .network
        }
    }

    private static func mapAuthError(_ error: AuthError) -> AppError {
        switch error {
        case .sessionMissing:
            .unauthorized
        default:
            .unknown(message: error.localizedDescription)
        }
    }

    private static func mapPostgrestError(_ error: PostgrestError) -> AppError {
        // Postgrest codes start with "PGRST"; Postgres SQLSTATE codes are
        // 5 chars. "P0429" is our own convention: RPCs raise it when
        // rl_check says the caller is over the sliding-window limit (see
        // the overlap_rpc migration). Everything else carries the server
        // message through as validation so the user sees something useful.
        switch error.code {
        case "PGRST301", "42501":
            .unauthorized
        case "P0429":
            .rateLimited
        default:
            .validation(error.message)
        }
    }
}
