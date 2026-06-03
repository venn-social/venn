#if DEBUG
    import SwiftUI

    // Reusable building blocks for the style preview pages. DEBUG-only.

    /// Cover placeholder shown until real cover art is available: a tonal tile,
    /// keyed to media kind, with the entry's leading initial.
    struct StyleCoverTile: View {
        @Environment(\.colorScheme)
        private var scheme
        let title: String
        let kind: MediaKind
        var height: CGFloat
        var cornerRadius: CGFloat = 16

        var body: some View {
            ZStack {
                StyleToken.coverTint(for: kind, scheme)
                Text(title.prefix(1))
                    .font(.system(size: height * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(StyleToken.coverGlyph(scheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(.rect(cornerRadius: cornerRadius))
        }
    }

    /// Compact rating label — a single accent star plus the value.
    struct StyleRatingLabel: View {
        @Environment(\.colorScheme)
        private var scheme
        let value: String

        var body: some View {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(StyleToken.accent)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StyleToken.ink(scheme))
            }
        }
    }

    /// A labelled statistic, used in the profile stat strip.
    struct StyleStatColumn: View {
        @Environment(\.colorScheme)
        private var scheme
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(StyleToken.ink(scheme))
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(StyleToken.inkSecondary(scheme))
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// venn's identity element: two intersecting marks plus a taste-overlap
    /// stat. The overlap primitive is the product's core idea, surfaced here
    /// as a compact, reusable badge.
    struct TasteOverlapBadge: View {
        @Environment(\.colorScheme)
        private var scheme
        let percent: Int
        let subtitle: String

        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(StyleToken.accent.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .offset(x: -12)
                    Circle()
                        .fill(StyleToken.ink(scheme).opacity(0.85))
                        .frame(width: 44, height: 44)
                        .offset(x: 12)
                        .blendMode(scheme == .dark ? .screen : .multiply)
                }
                .frame(width: 80)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(percent)% taste overlap")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(StyleToken.ink(scheme))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(StyleToken.inkSecondary(scheme))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(StyleToken.hairline(scheme).opacity(0.45), in: .rect(cornerRadius: 16))
        }
    }

    extension View {
        /// Lets the app's `GlassSkyBackground` (rendered by `RootView`) show
        /// through a preview page's scroll + navigation containers.
        func stylePreviewSurface() -> some View {
            scrollContentBackground(.hidden)
                .containerBackground(for: .navigation) { Color.clear }
        }
    }
#endif
