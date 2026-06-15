import Foundation
import Testing
@testable import Venn

@MainActor
struct OnboardingPhotoViewModelTests {
    @Test
    func cannotContinueWithoutAPickedPhoto() {
        let viewModel = makeViewModel()
        #expect(viewModel.canContinue == false)
    }

    @Test
    func submitUploadsThePickedBytesAndCompletes() async {
        let service = FakeProfileService()
        let viewModel = makeViewModel(service: service)
        let jpeg = Data([0xFF, 0xD8, 0x01])
        viewModel.selectedJPEG = jpeg
        #expect(viewModel.canContinue == true)

        await viewModel.submit()

        #expect(viewModel.state == .done)
        #expect(service.uploadedAvatarData == [jpeg])
    }

    @Test
    func failedUploadReturnsToPickingWithFlag() async {
        let service = FakeProfileService()
        service.uploadAvatarResult = .failure(AppError.server)
        let viewModel = makeViewModel(service: service)
        viewModel.selectedJPEG = Data([0xFF, 0xD8])

        await viewModel.submit()

        #expect(viewModel.state == .picking)
        #expect(viewModel.failed == true)
    }

    @Test
    func skipCompletesWithoutUploading() {
        let service = FakeProfileService()
        let viewModel = makeViewModel(service: service)

        viewModel.skip()

        #expect(viewModel.state == .done)
        #expect(service.uploadedAvatarData.isEmpty)
    }

    private func makeViewModel(
        service: FakeProfileService = FakeProfileService()
    ) -> OnboardingPhotoViewModel {
        OnboardingPhotoViewModel(userID: UUID(), service: service)
    }
}
