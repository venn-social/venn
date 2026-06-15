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

    /// Live ✓/✗ feedback while the user types. Advisory only — the DB
    /// unique constraint still decides at submit time.
    enum Availability: Equatable {
        case idle
        case checking
        case available(String)
        case taken(String)
        case invalid(ErrorReason)
    }

    var username = ""
    var displayName = ""
    private(set) var state: State = .editing
    private(set) var errorReason: ErrorReason?
    private(set) var availability: Availability = .idle

    let userID: UUID
    private let service: any OnboardingServicing
    private let availabilityDebounce: Duration
    private var availabilityTask: Task<Void, Never>?

    /// `availabilityDebounce` is injectable so tests can pass `.zero`.
    init(
        userID: UUID,
        service: any OnboardingServicing,
        availabilityDebounce: Duration = .milliseconds(350)
    ) {
        self.userID = userID
        self.service = service
        self.availabilityDebounce = availabilityDebounce
    }

    /// Debounced live check, called from the view on every keystroke.
    /// Local validation runs first (no network for a malformed handle);
    /// network failures quietly return to `.idle` — the submit path will
    /// surface real errors.
    func usernameChanged() {
        availabilityTask?.cancel()
        errorReason = nil
        let raw = username.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else {
            availability = .idle
            return
        }
        let handle: String
        switch Sanitize.handle(raw) {
        case let .valid(normalized):
            handle = normalized
        case let .invalid(reason):
            availability = .invalid(Self.usernameReason(for: reason))
            return
        }
        availability = .checking
        let delay = availabilityDebounce
        availabilityTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            do {
                let free = try await service.isUsernameAvailable(handle)
                guard !Task.isCancelled else { return }
                availability = free ? .available(handle) : .taken(handle)
            } catch {
                guard !Task.isCancelled else { return }
                availability = .idle
            }
        }
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
            availability = .taken(handle)
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
