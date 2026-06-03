#if DEBUG
    import Foundation

    /// A single feed item for the style preview: who did what, and the entry
    /// it refers to. DEBUG-only sample data — never touches real services.
    struct StyleActivity: Identifiable {
        let id = UUID()
        let author: String
        let action: String
        let timestamp: String
        let rating: String?
        let note: String?
        let entry: StyleEntry
    }

    /// A catalog entry (movie / show / book / album) for the style preview.
    struct StyleEntry: Identifiable {
        let id = UUID()
        let kind: MediaKind
        let title: String
        let creator: String
        let year: String
        /// Tile height used by the explore masonry layout.
        var tileHeight: CGFloat = 170
    }

    enum StyleSampleData {
        static let feed: [StyleActivity] = [
            StyleActivity(
                author: "Maya",
                action: "logged",
                timestamp: "2h",
                rating: "4.5",
                note: "quiet, devastating, exactly the right kind of Sunday film",
                entry: StyleEntry(kind: .movie, title: "Past Lives", creator: "Celine Song", year: "2023")
            ),
            StyleActivity(
                author: "Theo",
                action: "rated",
                timestamp: "5h",
                rating: "4.0",
                note: "season two has the restaurant anxiety and the family ache",
                entry: StyleEntry(kind: .show, title: "The Bear", creator: "Christopher Storer", year: "2022")
            ),
            StyleActivity(
                author: "Alex",
                action: "saved",
                timestamp: "1d",
                rating: nil,
                note: nil,
                entry: StyleEntry(
                    kind: .book,
                    title: "Tomorrow, and Tomorrow, and Tomorrow",
                    creator: "Gabrielle Zevin",
                    year: "2022"
                )
            ),
            StyleActivity(
                author: "Maya",
                action: "rated",
                timestamp: "2d",
                rating: "4.5",
                note: "still the standard for an album as a single sustained mood",
                entry: StyleEntry(kind: .album, title: "A Moon Shaped Pool", creator: "Radiohead", year: "2016")
            ),
        ]

        static let catalog: [StyleEntry] = [
            StyleEntry(kind: .movie, title: "Aftersun", creator: "Charlotte Wells", year: "2022", tileHeight: 210),
            StyleEntry(kind: .album, title: "Blonde", creator: "Frank Ocean", year: "2016", tileHeight: 160),
            StyleEntry(kind: .show, title: "Severance", creator: "Dan Erickson", year: "2022", tileHeight: 190),
            StyleEntry(kind: .book, title: "Normal People", creator: "Sally Rooney", year: "2018", tileHeight: 150),
            StyleEntry(kind: .movie, title: "Past Lives", creator: "Celine Song", year: "2023", tileHeight: 200),
            StyleEntry(kind: .album, title: "In Rainbows", creator: "Radiohead", year: "2007", tileHeight: 170),
            StyleEntry(kind: .show, title: "The Bear", creator: "Christopher Storer", year: "2022", tileHeight: 150),
            StyleEntry(kind: .book, title: "Tomorrow ×3", creator: "Gabrielle Zevin", year: "2022", tileHeight: 200),
        ]
    }
#endif
