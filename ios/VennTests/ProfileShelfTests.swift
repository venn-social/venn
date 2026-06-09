import Foundation
import Testing
@testable import Venn

struct ProfileShelfTests {
    @Test
    func collectionMapsToConsumedActions() {
        #expect(ProfileShelf.collection.actions == ["logged", "rated"])
    }

    @Test
    func watchlistMapsToSavedAction() {
        #expect(ProfileShelf.watchlist.actions == ["saved"])
    }

    @Test
    func titlesAreUserFacing() {
        #expect(ProfileShelf.collection.title == "Collection")
        #expect(ProfileShelf.watchlist.title == "Watchlist")
    }

    @Test
    func allCasesOrderedCollectionThenWatchlist() {
        #expect(ProfileShelf.allCases == [.collection, .watchlist])
    }
}
