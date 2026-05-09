import Foundation
import Observation

/// Drives the "Edit profile" sheet. Holds the editable fields, validates
/// them via `Sanitize`, and tracks the four states the form can be in:
/// editing, saving, saved, error.
///
/// Both `displayName` and `bio` are nullable in the `public.profiles`
/// schema. An empty input here is interpreted as "clear the column" and
/// sent as JSON `null`, which `Sanitize` itself does not allow for
/// `displayName` — so empty input bypasses the validator.
///
/// Keeps zero references to SwiftUI types so it's easy to unit-test
/// against a fake `ProfileServicing`.
@MainActor
@Observable
final class ProfileEditViewModel {
    enum State: Equatable {
        case editing
        case saving
        case saved
        case error(ErrorReason)
    }

    /// The view layer maps these to localized copy. Cases stay here so the
    /// view-model is free of `LocalizedStringKey` and trivially testable.
    enum ErrorReason: Equatable {
        case invalidDisplayName
        case invalidBio
        case offline
        case saveFailed
    }

    var displayName: String
    var bio: String
    var state: State = .editing

    let userID: UUID

    private let initialDisplayName: String
    private let initialBio: String
    private let service: any ProfileServicing

    init(
        userID: UUID,
        displayName: String?,
        bio: String?,
        service: any ProfileServicing
    ) {
        self.userID = userID
        self.displayName = displayName ?? ""
        self.bio = bio ?? ""
        initialDisplayName = displayName ?? ""
        initialBio = bio ?? ""
        self.service = service
    }

    /// True when at least one field has changed from its initial value and
    /// we're not mid-save. View binds the Save button's disabled state to
    /// this. Validation errors only surface on submit.
    var canSave: Bool {
        if case .saving = state { return false }
        if case .saved = state { return false }
        return displayName != initialDisplayName || bio != initialBio
    }

    /// Validate, transition to `.saving`, ask the service to update the
    /// row, then end in `.saved` or `.error`. Empty input clears the
    /// column (sends JSON `null`).
    func save() async {
        let displayNameValue: String?
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayNameValue = nil
        } else {
            switch Sanitize.displayName(displayName) {
            case let .valid(normalised):
                displayNameValue = normalised
            case .invalid:
                state = .error(.invalidDisplayName)
                return
            }
        }

        let bioValue: String?
        switch Sanitize.bio(bio) {
        case let .valid(normalised):
            bioValue = normalised.isEmpty ? nil : normalised
        case .invalid:
            state = .error(.invalidBio)
            return
        }

        state = .saving
        do {
            try await service.updateProfile(
                userID: userID,
                displayName: displayNameValue,
                bio: bioValue
            )
            state = .saved
        } catch let error as AppError {
            state = .error(reason(for: error))
        } catch {
            state = .error(.saveFailed)
        }
    }

    /// Translate a service-layer `AppError` into a UI-layer `ErrorReason`.
    /// Only network gets distinct copy today; everything else collapses to
    /// `.saveFailed` ("try again") because the user can't act on the
    /// distinction (a 429 / 5xx / RLS denial all read the same to them).
    private func reason(for error: AppError) -> ErrorReason {
        switch error {
        case .network: .offline
        case .unauthorized, .validation, .rateLimited, .server, .unknown: .saveFailed
        }
    }
}
