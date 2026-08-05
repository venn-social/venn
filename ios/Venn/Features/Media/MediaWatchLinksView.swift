import SwiftUI

/// Where you can watch this, for the device's region. Mirrors web's
/// `WatchLinks.tsx` in behaviour and copy (CLAUDE.md rule 17).
///
/// The region is always named. Streaming rights differ by country, so a
/// bare list of providers is a claim we can't support — "on Netflix" is
/// only ever true somewhere.
struct MediaWatchLinksView: View {
    let links: [WatchLink]
    let regionName: String?
    let kind: MediaKind

    var body: some View {
        // Only screen media has availability data — TMDB is the one
        // provider that carries it, so books and albums render nothing at
        // all rather than an empty section.
        if kind == .movie || kind == .show, !links.isEmpty {
            MediaDetailSection(title: heading) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(links, id: \.self) { link in
                            providerChip(link)
                        }
                    }

                    Text("Availability from TMDB. Rights change often and vary by country.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
    }

    private var heading: LocalizedStringKey {
        if let regionName {
            "Where to watch in \(regionName)"
        } else {
            "Where to watch"
        }
    }

    @ViewBuilder
    private func providerChip(_ link: WatchLink) -> some View {
        if let url = link.url {
            Link(destination: url) { chipBody(link) }
                .accessibilityLabel("\(link.kind.label) on \(link.provider)")
        } else {
            chipBody(link)
        }
    }

    private func chipBody(_ link: WatchLink) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let logoURL = link.logoURL {
                AsyncImage(url: logoURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    SwiftUI.Color.clear
                }
                .frame(width: 20, height: 20)
                .clipShape(.rect(cornerRadius: Theme.Radius.sm / 2))
            }
            Text(link.provider)
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(link.kind.label)
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .overlay(
            Capsule().strokeBorder(Theme.Color.separator, lineWidth: 1)
        )
    }
}

#Preview {
    MediaWatchLinksView(
        links: [
            WatchLink(provider: "Netflix", kind: .stream, url: nil, logoURL: nil),
            WatchLink(provider: "Apple TV", kind: .rent, url: nil, logoURL: nil),
        ],
        regionName: "United Kingdom",
        kind: .movie
    )
    .padding(Theme.Spacing.lg)
}
