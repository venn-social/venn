import Supabase
import SwiftUI

#if DEBUG
    /// DEBUG-only harness that walks the composer's log flow (pick → rate →
    /// submit, and the watchlist shortcut) against an in-memory stub, so the
    /// write path can be UI-tested without creating rows in the shared
    /// remote DB. Booted by the `-previewComposer` launch arg (see
    /// `RootView`).
    ///
    /// Pre-seeds `selectedCandidate` so the shell opens straight on the
    /// media detail page — mirrors `ComposerSheetView`'s own `#Preview`.
    struct ComposerPreviewView: View {
        @State private var isDone = false
        @State private var viewModel = ComposerViewModel(service: StubComposerService())
        @State private var authState = AuthState.debugSignedIn()

        var body: some View {
            Group {
                if isDone {
                    doneScreen
                } else {
                    ComposerSheetView(viewModel: viewModel)
                }
            }
            .environment(authState)
            .task {
                if viewModel.selectedCandidate == nil {
                    viewModel.pick(Self.candidate)
                }
            }
            .onChange(of: viewModel.submitState) { _, state in
                if state == .submitted { isDone = true }
            }
        }

        private var doneScreen: some View {
            Screen {
                VStack(spacing: Theme.Spacing.md) {
                    VennMark(size: 72)
                    Text("Logged")
                        .font(Theme.Font.title)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .accessibilityIdentifier("composer_preview_done")
                }
            }
        }

        private static let candidate = MediaCandidate(
            title: "Past Lives",
            primaryCreator: "Celine Song",
            year: 2023,
            coverURL: nil,
            overview: "Two childhood sweethearts reunite in New York City for one fateful week.",
            externalID: "976573",
            externalSource: .tmdb,
            kind: .movie
        )
    }

    /// In-memory composer stub — resolves immediately so the UI test doesn't
    /// wait on a network round trip (unlike `PreviewComposerService`, which
    /// deliberately never resolves for visual-only Xcode Previews).
    private struct StubComposerService: ComposerServicing {
        func search(query _: String, kind _: MediaKind, page _: Int) async throws -> [MediaCandidate] {
            []
        }

        func log(
            candidate: MediaCandidate,
            authorID: UUID,
            action: PostAction,
            rating: Double?,
            caption: String?
        ) async throws -> Post {
            Post(
                id: UUID(),
                authorID: authorID,
                mediaID: UUID(),
                action: action,
                rating: rating,
                caption: caption,
                createdAt: Date()
            )
        }
    }

    private extension AuthState {
        /// A stub-backed `AuthState` pre-signed-in with the shared debug
        /// session, so `ComposerViewModel.submit`/`addToWatchlist` (which
        /// read `authState.status` for the author id) have something to work
        /// with without a real sign-in.
        static func debugSignedIn() -> AuthState {
            let state = AuthState(service: NeverCalledAuthService())
            state.status = .signedIn(DebugSession.make())
            return state
        }
    }

    /// Every method traps — this shell only reads `authState.status`, it
    /// never calls the service.
    private struct NeverCalledAuthService: AuthServicing {
        var sessionChanges: AsyncStream<Session?> {
            AsyncStream { $0.finish() }
        }

        func currentSession() async throws -> Session? {
            nil
        }

        func sendMagicLink(email _: String, redirectTo _: URL) async throws {}
        func handleCallback(_: URL) async throws {}
        func signOut() async throws {}
        func signInAnonymously() async throws {}
    }

    #Preview {
        ComposerPreviewView()
    }
#endif
