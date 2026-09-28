import SwiftUI

/// A single feed entry, built around its artwork. Mirrors web's
/// `FeedRow.tsx` (CLAUDE.md rule 17).
///
/// Everything that describes the title sits *on* the title: the name, the
/// year and creator, the rating, and the like and comment controls the host
/// passes in. What stays outside the artwork is only what is not about it —
/// who logged it, when, and what they said.
///
/// It used to be an image with a paragraph of chrome under it: attribution
/// above, then title, metadata, rating and caption stacked below, each on
/// its own line at its own size. Five bands of text around one picture, and
/// a post roughly a third taller than this one for no extra information.
///
/// The cover opens the title's detail screen, so every host has to register
/// `.navigationDestination(for: Media.self)` — the row pushes a value, not
/// a view.
struct FeedRow<Overlay: View>: View {
    let feedPost: FeedPost

    /// The signed-in user, so the cover can offer Log / Add to Watchlist.
    /// Nil when signed out; equal to the author on your own posts, where
    /// there is nothing to offer that you do not already have.
    var viewerID: UUID?

    /// Runs the chosen action. The row does not own a service — the host
    /// screen does — so it hands the choice back up.
    var onLibraryAction: ((LibraryQuickAction) -> Void)?

    /// Like and comment, laid on the foot of the artwork beside the
    /// metadata. Empty on the permalink, which shows the same controls
    /// under the row and would otherwise show them twice.
    @ViewBuilder var overlay: () -> Overlay

    private var showsLibraryMenu: Bool {
        guard let viewerID, onLibraryAction != nil else { return false }
        return viewerID != feedPost.author.id
    }

    private var authorName: String {
        feedPost.author.displayName ?? feedPost.author.username
    }

    /// "2023 · Celine Song" — whichever of year / creator is present.
    private var metadata: String {
        [feedPost.media.year.map(String.init), feedPost.media.primaryCreator]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            attribution
            artwork

            if let caption = feedPost.post.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The name is a link to the profile; the verb after it is not. Accent
    /// is this design system's signal for "interactive", and the name once
    /// read as the same grey as the verb — nothing suggested it could be
    /// tapped.
    private var attribution: some View {
        HStack(spacing: Theme.Spacing.xs) {
            NavigationLink(value: feedPost.author) {
                HStack(spacing: Theme.Spacing.xs) {
                    AvatarBadge(
                        name: authorName,
                        avatarURL: feedPost.author.avatarURL,
                        size: 22
                    )
                    Text(authorName)
                        .font(Theme.Font.caption.weight(.semibold))
                        .foregroundStyle(Theme.Color.accent)
                }
            }
            .buttonStyle(.plain)

            Text(feedPost.post.action.rawValue)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)

            Spacer(minLength: Theme.Spacing.sm)
            Text(RelativeTime.short(from: feedPost.post.createdAt))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    /// The cover, and everything printed on it.
    ///
    /// The scrims are overlays rather than ZStack siblings so they cannot
    /// take a tap meant for the artwork underneath — each is explicitly not
    /// hit-testable, and only the controls and the ⋯ accept touches. That
    /// is the same split web makes with `pointer-events`.
    private var artwork: some View {
        NavigationLink(value: feedPost.media) {
            MediaCoverTile(
                title: feedPost.media.title,
                kind: feedPost.media.kind,
                coverURL: feedPost.media.coverURL,
                height: nil,
                cornerRadius: 0
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomBar }
        .overlay(alignment: .topLeading) { libraryMenu }
        // Clipped here rather than inside the tile, so the scrims take the
        // corner radius with it instead of squaring off over it.
        .clipShape(.rect(cornerRadius: Theme.Radius.lg))
    }

    /// The rating, on a shorter scrim of its own.
    ///
    /// That scrim is also what lets the ⋯ go bare: both sit on a gradient
    /// rather than on whatever the artwork happens to be underneath them.
    private var topBar: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            if let rating = feedPost.post.rating {
                RatingLabel(value: rating, valueColor: .white)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .padding(Theme.Spacing.sm)
            }
        }
    }

    /// Title, metadata and the host's controls, on the scrim at the foot.
    ///
    /// Both text lines clamp to one. A cover is a fixed height and a long
    /// title is not, so the alternative is a scrim that grows until it
    /// swallows the artwork it is captioning.
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(feedPost.media.title)
                .font(Theme.Font.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: Theme.Spacing.xs) {
                if !metadata.isEmpty {
                    Text(metadata)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Spacing.sm)
                overlay()
            }
        }
        .padding(Theme.Spacing.md)
        // Headroom for the gradient to fade through before it reaches the
        // text, rather than stopping abruptly above it.
        .padding(.top, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.45), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        // Two shadows' worth of separation in one: enough that white
        // survives a pale cover, and that a busy one cannot swallow it.
        .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
    }

    /// Log / Add to Watchlist, from the artwork itself.
    ///
    /// A visible control rather than the long-press it used to be. Web now
    /// shows a persistent ⋯ on touch, and a menu you can only find by
    /// holding down a picture is a menu most people never find.
    @ViewBuilder private var libraryMenu: some View {
        if showsLibraryMenu {
            Menu {
                ForEach(LibraryQuickAction.allCases) { action in
                    Button(action.title, systemImage: action.systemImage) {
                        onLibraryAction?(action)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(Theme.Font.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Options for \(feedPost.media.title)")
            .padding(Theme.Spacing.sm)
        }
    }
}

extension FeedRow where Overlay == EmptyView {
    /// The row without social controls — the permalink, which shows its own
    /// under the post.
    init(
        feedPost: FeedPost,
        viewerID: UUID? = nil,
        onLibraryAction: ((LibraryQuickAction) -> Void)? = nil
    ) {
        self.init(
            feedPost: feedPost,
            viewerID: viewerID,
            onLibraryAction: onLibraryAction
        ) {
            EmptyView()
        }
    }
}

#if DEBUG
    /// Sample data for the previews below. DEBUG-only, and deliberately not
    /// shared with the services — a preview that can reach production code
    /// paths is how fake rows end up in real ones.
    extension FeedPost {
        static func preview(
            title: String = "Past Lives",
            kind: MediaKind = .movie,
            year: Int? = 2023,
            creator: String? = "Celine Song",
            coverURL: URL? = URL(string: "https://image.tmdb.org/t/p/w500/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg"),
            rating: Double? = 8.7,
            caption: String? = "Genuinely the best thing I've seen all year."
        ) -> FeedPost {
            let authorID = UUID()
            let mediaID = UUID()
            return FeedPost(
                post: Post(
                    id: UUID(),
                    authorID: authorID,
                    mediaID: mediaID,
                    action: .logged,
                    rating: rating,
                    caption: caption,
                    createdAt: Date().addingTimeInterval(-3 * 3600)
                ),
                media: Media(
                    id: mediaID,
                    kind: kind,
                    title: title,
                    year: year,
                    primaryCreator: creator,
                    coverURL: coverURL,
                    externalID: nil,
                    externalSource: nil,
                    createdAt: Date()
                ),
                author: UserProfile(
                    id: authorID,
                    username: "charles",
                    displayName: "Charles",
                    avatarURL: nil,
                    bio: nil,
                    isPrivate: false,
                    language: .en,
                    createdAt: Date()
                )
            )
        }
    }

    #Preview("Light") {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    FeedRow(feedPost: .preview())
                    // The cases that decide whether the scrim works: a long
                    // title with nothing to sit beside it, and no cover at
                    // all, where the scrim lies on the placeholder tile.
                    FeedRow(
                        feedPost: .preview(
                            title: "Everything Everywhere All at Once and Then Some More",
                            creator: "Daniel Kwan & Daniel Scheinert",
                            rating: nil
                        )
                    )
                    FeedRow(feedPost: .preview(title: "Blonde", creator: nil, coverURL: nil))
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }

    #Preview("Dark") {
        NavigationStack {
            ScrollView {
                FeedRow(feedPost: .preview())
                    .padding(Theme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }
#endif
