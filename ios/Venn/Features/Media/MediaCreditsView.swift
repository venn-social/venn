import SwiftUI

/// Who made this, and who's in it.
///
/// The two are separate sections because they answer different questions,
/// and the authorial one is named for the medium: a book has an author, an
/// album an artist, a film a director. Copy matches web (CLAUDE.md rule 17).
struct MediaCreditsView: View {
    let creators: [Credit]
    let cast: [Credit]

    var body: some View {
        if !creators.isEmpty {
            MediaDetailSection(title: creatorsHeading) {
                Text(creators.map(\.name).formatted(.list(type: .and)))
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if !cast.isEmpty {
            MediaDetailSection(title: "Cast") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(cast, id: \.self) { person in
                        castRow(person)
                    }
                }
            }
        }
    }

    /// Driven by the role the provider gave us rather than by media kind:
    /// the fetchers already decided what "Author" means for OpenLibrary and
    /// "Artist" for MusicBrainz, and re-deriving it here would let the two
    /// disagree.
    private var creatorsHeading: LocalizedStringKey {
        switch creators.first?.role {
        case "Author": "Author"
        case "Artist": "Artist"
        default: "Directed by"
        }
    }

    private func castRow(_ person: Credit) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(person.name)
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.Color.textPrimary)
            if let role = person.role, !role.isEmpty {
                Text("as \(role)")
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        MediaCreditsView(
            creators: [Credit(name: "Celine Song", role: "Director")],
            cast: [
                Credit(name: "Greta Lee", role: "Nora"),
                Credit(name: "Teo Yoo", role: "Hae Sung"),
            ]
        )
    }
    .padding(Theme.Spacing.lg)
}
