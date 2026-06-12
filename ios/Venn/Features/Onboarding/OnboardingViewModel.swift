import Foundation
import Observation

/// Drives the username-claim screen shown once after first sign-in.
/// Validation mirrors `Sanitize.handle` (and therefore the DB CHECK
/// constraint); uniqueness is decided by the database on submit — no
/// availability pre-check, no race.
@MainActor
@Observable
final class OnboardingViewModel {
    enum State: Equatable {
        case editing
        case submitting
        case done
    }

    /// Flow-specific failure reasons rendered inline under the fields.
    /// Kept feature-local (like `AuthViewModel.ErrorReason`) — these need
    /// copy a generic `LoadErrorReason` can't express.
    enum ErrorReason: Equatable {
        case usernameTooShort
        case usernameTooLong
        case usernameInvalidCharacters
        case usernameTaken
        case displayNameTooLong
        case offline
        case unknown
    }

    var username = ""
    var displayName = ""
    private(set) var state: State = .editing
    private(set) var errorReason: ErrorReason?

    let userID: UUID
    private let service: any OnboardingServicing

    init(userID: UUID, service: any OnboardingServicing) {
        self.userID = userID
        self.service = service
    }

    var canSubmit: Bool {
        state == .editing && !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func submit() async {
        guard canSubmit else { return }
        errorReason = nil

        let handle: String
        switch Sanitize.handle(username) {
        case let .valid(normalized):
            handle = normalized
        case let .invalid(reason):
            errorReason = Self.usernameReason(for: reason)
            return
        }

        var name: String?
        if !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            switch Sanitize.displayName(displayName) {
            case let .valid(normalized):
                name = normalized
            case .invalid:
                errorReason = .displayNameTooLong
                return
            }
        }

        state = .submitting
        do {
            try await service.createProfile(userID: userID, username: handle, displayName: name)
            state = .done
        } catch is UsernameTakenError {
            errorReason = .usernameTaken
            state = .editing
        } catch let error as AppError {
            errorReason = LoadErrorReason(error) == .offline ? .offline : .unknown
            state = .editing
        } catch {
            errorReason = .unknown
            state = .editing
        }
    }

    private static func usernameReason(for reason: Sanitize.Reason) -> ErrorReason {
        switch reason {
        case .empty, .tooShort: .usernameTooShort
        case .tooLong: .usernameTooLong
        case .invalidCharacters, .invalidFormat: .usernameInvalidCharacters
        }
    }
}
