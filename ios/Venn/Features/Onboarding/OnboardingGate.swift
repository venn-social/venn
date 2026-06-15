import SwiftUI

/// Sits between "signed in" and the main app: routes to `OnboardingView`
/// until a `profiles` row exists, then to `MainView`. Magic-link sign-in
/// only proves an email — this gate is what guarantees every signed-in
/// user inside the app has a profile (so Feed/Profile/Search never see a
/// half-initialized account).
struct OnboardingGate: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    let userID: UUID

    private enum GateState: Equatable {
        case checking
        case needsOnboarding
        case needsPhoto
        case ready
        case error(LoadErrorReason)
    }

    @State private var state: GateState = .checking

    var body: some View {
        switch state {
        case .checking:
            DeferredLoadingView()
                .task { await check() }
        case .needsOnboarding:
            OnboardingView(viewModel: OnboardingViewModel(
                userID: userID,
                service: OnboardingService(client: clientProvider.client)
            )) {
                state = .needsPhoto
            }
        case .needsPhoto:
            OnboardingPhotoView(viewModel: OnboardingPhotoViewModel(
                userID: userID,
                service: ProfileService(client: clientProvider.client)
            )) {
                state = .ready
            }
        case .ready:
            MainView()
        case let .error(reason):
            Screen {
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load your account") {
                    state = .checking
                }
            }
        }
    }

    private func check() async {
        do {
            let exists = try await OnboardingService(client: clientProvider.client)
                .hasProfile(userID: userID)
            state = exists ? .ready : .needsOnboarding
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}
