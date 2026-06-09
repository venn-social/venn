import SwiftUI

/// The standard error branch for any `LoadState.error` render. Wraps
/// `EmptyStateView` with consistent icon + copy per `LoadErrorReason`, so
/// screens don't each hand-roll the same offline/unknown conditionals.
///
/// `unknownTitle` names what failed for the `.unknown` case ("Couldn't
/// load the feed") — offline and rate-limited copy is deliberately
/// identical app-wide. Pass `retry` to show a "Try again" button.
struct ErrorStateView: View {
    let reason: LoadErrorReason
    var unknownTitle: LocalizedStringKey = "Something went wrong"
    var retry: (() -> Void)?

    var body: some View {
        EmptyStateView(
            systemImage: systemImage,
            title: title,
            message: message,
            actionTitle: retry == nil ? nil : "Try again",
            action: retry
        )
    }

    private var systemImage: String {
        switch reason {
        case .offline: "wifi.slash"
        case .rateLimited: "hourglass"
        case .unknown: "exclamationmark.triangle"
        }
    }

    private var title: LocalizedStringKey {
        switch reason {
        case .offline: "You're offline"
        case .rateLimited: "Too many requests"
        case .unknown: unknownTitle
        }
    }

    private var message: LocalizedStringKey {
        switch reason {
        case .offline: "Check your connection and try again."
        case .rateLimited: "Give it a moment, then try again."
        case .unknown: "Something went wrong on our end. Try again in a moment."
        }
    }
}

#Preview("offline") {
    ErrorStateView(reason: .offline) {}
}

#Preview("unknown, named surface") {
    ErrorStateView(reason: .unknown, unknownTitle: "Couldn't load the feed") {}
}

#Preview("no retry") {
    ErrorStateView(reason: .rateLimited)
}
