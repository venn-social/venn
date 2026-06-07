import SwiftUI

/// Sheet wrapper for the log-it composer flow.
///
/// Hosts a NavigationStack that starts at `MediaDetailView` and pushes
/// `RatingView` when the user taps "Log it". Dismisses automatically
/// when the submit completes or the user cancels.
struct ComposerSheetView: View {
    @Bindable var viewModel: ComposerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let candidate = viewModel.selectedCandidate {
                MediaDetailView(candidate: candidate, viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                viewModel.clearPick()
                                dismiss()
                            }
                        }
                    }
            }
        }
        .onChange(of: viewModel.submitState) { _, state in
            if state == .submitted { dismiss() }
        }
    }
}

// MARK: - Media detail page

private struct MediaDetailView: View {
    let candidate: MediaCandidate
    @Bindable var viewModel: ComposerViewModel
    @Environment(AuthState.self) private var authState

    @State private var pushRating = false

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    coverAndHeader
                    if let overview = candidate.overview {
                        overviewSection(overview)
                    }
                    Spacer(minLength: Theme.Spacing.xl)
                    actionButtons
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(candidate.title)
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
        }
        .navigationDestination(isPresented: $pushRating) {
            RatingView(viewModel: viewModel)
        }
    }

    // MARK: - Cover + header

    private var coverAndHeader: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            coverImage
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(candidate.title)
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let creator = candidate.primaryCreator {
                    Text(creator)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    if let year = candidate.year {
                        Text(verbatim: "\(year)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    kindBadge(candidate.kind)
                }
                .padding(.top, Theme.Spacing.xxs)
            }
        }
    }

    private var coverImage: some View {
        AsyncImage(url: candidate.coverURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                Image(systemName: candidate.kind.placeholderImage)
                    .font(.largeTitle)
                    .foregroundStyle(Theme.Color.accent)
            }
        }
        .frame(width: 100, height: 150)
        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
        .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))
    }

    private func kindBadge(_ kind: MediaKind) -> some View {
        Text(kind.displayName.capitalized)
            .font(Theme.Font.caption.weight(.semibold))
            .foregroundStyle(Theme.Color.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.Color.accent.opacity(0.12), in: Capsule())
    }

    // MARK: - Overview

    private func overviewSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Overview")
                .font(Theme.Font.callout.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
            Text(text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                pushRating = true
            } label: {
                Text("Log it")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                Task { await handleWatchlist() }
            } label: {
                Text("Add to Watchlist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(viewModel.submitState == .submitting)
        }
    }

    private func handleWatchlist() async {
        guard case let .signedIn(session) = authState.status else { return }
        await viewModel.addToWatchlist(authorID: session.user.id)
    }
}

// MARK: - Rating page

private struct RatingView: View {
    @Bindable var viewModel: ComposerViewModel
    @Environment(AuthState.self) private var authState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ratingSection
                    captionSection
                    feedToggle
                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
            .overlay(alignment: .bottomTrailing) {
                skipButton
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .navigationTitle("How was it?")
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                finishButton
            }
        }
    }

    // MARK: - Rating chips

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Rate it")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            HStack(spacing: Theme.Spacing.md) {
                ratingChip(choice: .love, emoji: "❤️", label: "Love")
                ratingChip(choice: .like, emoji: "👍", label: "Like")
                ratingChip(choice: .dislike, emoji: "👎", label: "Dislike")
            }
        }
    }

    private func ratingChip(
        choice: ComposerViewModel.RatingChoice,
        emoji: String,
        label: String
    ) -> some View {
        let selected = viewModel.ratingChoice == choice
        return Button {
            viewModel.ratingChoice = selected ? nil : choice
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Text(emoji).font(.title)
                Text(label)
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(selected ? Theme.Color.accent : Theme.Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                selected
                    ? Theme.Color.accent.opacity(0.15)
                    : Theme.Color.surface,
                in: .rect(cornerRadius: Theme.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        selected ? Theme.Color.accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Caption

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Comments (optional)")
                .font(Theme.Font.callout.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)

            TextField(
                "Say something about it…",
                text: $viewModel.caption,
                axis: .vertical
            )
            .lineLimit(3...6)
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))
        }
    }

    // MARK: - Post to feed toggle

    private var feedToggle: some View {
        Toggle(isOn: $viewModel.postToFeed) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Post to feed?")
                    .font(Theme.Font.body.weight(.medium))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("Share this with your followers")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .tint(Theme.Color.accent)
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))
    }

    // MARK: - Buttons

    private var skipButton: some View {
        Button {
            viewModel.ratingChoice = nil
            Task { await handleSubmit() }
        } label: {
            Text("Skip")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var finishButton: some View {
        switch viewModel.submitState {
        case .ready, .error:
            Button("Finish") {
                Task { await handleSubmit() }
            }
            .fontWeight(.semibold)
            .disabled(!viewModel.canSubmit)
        case .submitting:
            ProgressView().controlSize(.small)
        case .submitted:
            EmptyView()
        }
    }

    private func handleSubmit() async {
        guard case let .signedIn(session) = authState.status else { return }
        await viewModel.submit(authorID: session.user.id)
    }
}

// MARK: - MediaKind helpers

private extension MediaKind {
    var placeholderImage: String {
        switch self {
        case .movie: "film"
        case .show: "tv"
        case .book: "book.closed"
        case .album: "music.note"
        }
    }
}

// MARK: - Button styles

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Theme.Color.accent.opacity(configuration.isPressed ? 0.7 : 1),
                in: .rect(cornerRadius: Theme.Radius.md)
            )
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.body.weight(.medium))
            .foregroundStyle(Theme.Color.accent)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Theme.Color.accent.opacity(configuration.isPressed ? 0.15 : 0.1),
                in: .rect(cornerRadius: Theme.Radius.md)
            )
    }
}

#Preview {
    let vm = ComposerViewModel(service: PreviewComposerService())
    vm.pick(MediaCandidate(
        title: "Past Lives",
        primaryCreator: "Celine Song",
        year: 2023,
        coverURL: nil,
        overview: "Two childhood sweethearts are separated when Nora's family emigrates from South Korea. Two decades later, they are reunited in New York City for one fateful week.",
        externalID: "976573",
        externalSource: .tmdb,
        kind: .movie
    ))
    return ComposerSheetView(viewModel: vm)
        .environment(AppConfig.preview)
        .environment(SupabaseClientProvider.preview)
        .environment(AuthState(service: AuthService(client: SupabaseClientProvider.preview.client)))
        .environment(AppearanceSettings())
}

/// Preview-only service that never resolves (sheet is for visual inspection).
private final class PreviewComposerService: ComposerServicing, @unchecked Sendable {
    func search(query _: String, kind _: MediaKind, page _: Int) async throws -> [MediaCandidate] {
        []
    }

    func log(
        candidate _: MediaCandidate,
        authorID _: UUID,
        action _: PostAction,
        rating _: Double?,
        caption _: String?
    ) async throws -> Post {
        try await Task.sleep(for: .seconds(60))
        throw AppError.unknown(message: "preview")
    }
}
