#if DEBUG
    import SwiftUI

    /// Profile page for the visual style preview: an identity block, a stat
    /// strip, the taste-overlap badge, and a gallery of recent entries.
    /// DEBUG-only.
    struct ProfilePreviewPage: View {
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StyleIdentityBlock(
                            name: "Maya Chen",
                            handle: "@maya",
                            bio: "movies that linger, loud dinners, albums with one perfect skip"
                        )
                        StyleStatStrip(logged: "128", saved: "34", rated: "19")
                        TasteOverlapBadge(percent: 62, subtitle: "with people you follow")
                        recentlyLogged
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
                .stylePreviewSurface()
            }
        }

        private var recentlyLogged: some View {
            VStack(alignment: .leading, spacing: 12) {
                StyleSectionHeader(title: "Recently logged")
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(StyleSampleData.catalog.prefix(6)) { entry in
                        StyleCoverTile(title: entry.title, kind: entry.kind, height: 128, cornerRadius: 12)
                    }
                }
            }
        }
    }

    /// Avatar, name and handle on one line, with the bio beneath.
    private struct StyleIdentityBlock: View {
        @Environment(\.colorScheme)
        private var scheme
        let name: String
        let handle: String
        let bio: String

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(StyleToken.accent.opacity(scheme == .dark ? 0.22 : 0.12))
                        Text(name.prefix(1))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(StyleToken.accent)
                    }
                    .frame(width: 66, height: 66)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(StyleToken.ink(scheme))
                        Text(handle)
                            .font(.system(size: 15))
                            .foregroundStyle(StyleToken.inkSecondary(scheme))
                    }
                    Spacer(minLength: 0)
                }

                Text(bio)
                    .font(.system(size: 15))
                    .foregroundStyle(StyleToken.inkSecondary(scheme))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Evenly-weighted stat strip with hairline dividers in a soft container.
    private struct StyleStatStrip: View {
        @Environment(\.colorScheme)
        private var scheme
        let logged: String
        let saved: String
        let rated: String

        var body: some View {
            HStack(spacing: 0) {
                StyleStatColumn(value: logged, label: "logged")
                divider
                StyleStatColumn(value: saved, label: "saved")
                divider
                StyleStatColumn(value: rated, label: "rated")
            }
            .padding(.vertical, 16)
            .background(StyleToken.hairline(scheme).opacity(0.45), in: .rect(cornerRadius: 16))
        }

        private var divider: some View {
            Rectangle()
                .fill(StyleToken.hairline(scheme))
                .frame(width: 1, height: 30)
        }
    }

    /// Section heading used between profile sections.
    private struct StyleSectionHeader: View {
        @Environment(\.colorScheme)
        private var scheme
        let title: String

        var body: some View {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(StyleToken.ink(scheme))
                .padding(.top, 4)
        }
    }

    #Preview("light") {
        ZStack { Theme.Color.background
            ProfilePreviewPage()
        }
        .preferredColorScheme(.light)
    }

    #Preview("dark") {
        ZStack { Theme.Color.background
            ProfilePreviewPage()
        }
        .preferredColorScheme(.dark)
    }
#endif
