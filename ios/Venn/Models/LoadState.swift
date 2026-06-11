import Foundation

/// The one shared state machine for every "load a thing and render it"
/// screen. View-models expose `LoadState<...>` (usually through a
/// `typealias State`), views pattern-match on it, and `ErrorStateView`
/// renders the error branch. Defined once here so features don't each
/// re-declare an identical enum (Feed, Explorer, Profile, and Library
/// all did before this existed).
enum LoadState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case error(LoadErrorReason)
}

/// UI-layer reason a load or submit failed. The view layer maps these to
/// localized copy (see `ErrorStateView`). Keeping cases — rather than
/// user-facing strings — in the view-model keeps it free of
/// `LocalizedStringKey` and easy to test.
///
/// Only reasons the user can act on get distinct cases: reconnect
/// (`.offline`), wait (`.rateLimited`). A 401 / validation / 5xx all read
/// the same to the user ("something went wrong, retry"), so they collapse
/// to `.unknown`. Flow-specific reasons (invalid email, invalid bio) stay
/// in their feature's own enum — see `AuthViewModel.ErrorReason`.
enum LoadErrorReason: Equatable {
    case offline
    case rateLimited
    case unknown

    /// Single mapping site from the service-layer `AppError` (ADR 0006).
    init(_ error: AppError) {
        self = switch error {
        case .network: .offline
        case .rateLimited: .rateLimited
        case .unauthorized, .validation, .server, .unknown: .unknown
        }
    }
}

/// Search-shaped sibling of `LoadState` for debounced query screens.
/// `.idle` (no query yet) is distinct from `.searching` and from an empty
/// `.results` payload, which renders as "no results" copy. Shared by the
/// composer's media search and the Explorer people search.
enum SearchState<Value: Equatable>: Equatable {
    case idle
    case searching
    case results(Value)
    case error(LoadErrorReason)
}
