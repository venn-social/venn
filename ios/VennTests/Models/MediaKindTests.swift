import Testing
@testable import Venn

/// Pins the per-kind UI surfaces — a new `MediaKind` case must come with
/// a display name and an SF Symbol, and these tests force that decision.
struct MediaKindTests {
    @Test
    func everyKindHasADisplayName() {
        #expect(MediaKind.movie.displayName == "movie")
        #expect(MediaKind.show.displayName == "show")
        #expect(MediaKind.book.displayName == "book")
        #expect(MediaKind.album.displayName == "album")
    }

    @Test
    func everyKindHasASystemImage() {
        #expect(MediaKind.movie.systemImage == "film")
        #expect(MediaKind.show.systemImage == "tv")
        #expect(MediaKind.book.systemImage == "book.closed")
        #expect(MediaKind.album.systemImage == "music.note")
    }

    @Test
    func kindsRoundTripTheirRawValues() {
        for kind in MediaKind.allCases {
            #expect(MediaKind(rawValue: kind.rawValue) == kind)
        }
    }
}
