import SwiftUI

/// Where you can actually watch, read, or listen to this. Mirrors web's
/// `WatchLinks.tsx` in behaviour and copy (CLAUDE.md rule 17).
///
/// Screen availability comes from TMDB and is real: these providers carry
/// the title in this region, and the region is always named, because rights
/// differ by country and "on Netflix" is only ever true somewhere.
///
/// Books and albums are a weaker claim and are labelled as one. No catalog
/// we read holds availability for them, so their links run a search on each
/// service rather than confirming it's stocked.
struct MediaWatchLinksView: View {
    let links: [WatchLink]
    let regionName: String?
    let kind: MediaKind

    private var searchOnly: Bool {
        kind == .book || kind == .album
    }

    var body: some View {
        if !links.isEmpty {
            MediaDetailSection(title: heading) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(links, id: \.self) { link in
                            providerChip(link)
                        }
                    }

                    Text(footnote)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
    }

    private var heading: LocalizedStringKey {
        if searchOnly {
            kind == .book ? "Where to read" : "Where to listen"
        } else if let regionName {
            "Where to watch in \(regionName)"
        } else {
            "Where to watch"
        }
    }

    private var footnote: LocalizedStringKey {
        searchOnly
            ? "These search each service — we can't tell whether it's stocked."
            : "Availability from TMDB. Rights change often and vary by country."
    }

    @ViewBuilder
    private func providerChip(_ link: WatchLink) -> some View {
        if let url = link.url {
            Link(destination: url) { chipBody(link) }
                .accessibilityLabel("\(link.kind.label(for: kind)) on \(link.provider)")
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
            Text(link.kind.label(for: kind))
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

#Preview("Screen") {
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

#Preview("Book") {
    MediaWatchLinksView(
        links: Destinations.readOrListenLinks(
            kind: .book,
            title: "Kafka on the Shore",
            creator: "Haruki Murakami",
            region: "GB"
        ),
        regionName: "United Kingdom",
        kind: .book
    )
    .padding(Theme.Spacing.lg)
}
