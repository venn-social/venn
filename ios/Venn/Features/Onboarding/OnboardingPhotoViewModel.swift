import Foundation
import Observation

/// Drives the optional "add a profile photo" step (2 of 2) of onboarding.
/// The profile row already exists by the time this runs, so upload goes
/// through the same `ProfileServicing.uploadAvatar` path the edit sheet
/// uses. Skipping is always allowed — a photo should never block entry.
@MainActor
@Observable
final class OnboardingPhotoViewModel {
    enum State: Equatable {
        case picking
        case uploading
        case done
    }

    /// Upload-ready JPEG bytes, set by the view after `AvatarCropperView`
    /// processing. Nil until a photo is picked.
    var selectedJPEG: Data?
    private(set) var state: State = .picking
    private(set) var failed = false

    let userID: UUID
    private let service: any ProfileServicing

    init(userID: UUID, service: any ProfileServicing) {
        self.userID = userID
        self.service = service
    }

    var canContinue: Bool {
        selectedJPEG != nil && state == .picking
    }

    /// Upload the picked photo. Failure returns to `.picking` with a flag
    /// the view renders inline — the user can retry or just skip.
    func submit() async {
        guard let jpeg = selectedJPEG, state == .picking else { return }
        failed = false
        state = .uploading
        do {
            _ = try await service.uploadAvatar(userID: userID, jpegData: jpeg)
            state = .done
        } catch {
            failed = true
            state = .picking
        }
    }

    func skip() {
        state = .done
    }
}
