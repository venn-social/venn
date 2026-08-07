import Foundation
import Testing
@testable import Venn

/// The side menu's contents and order. Mirrors web's `SideMenu.test.tsx` —
/// the two menus have to hold the same four destinations in the same order,
/// or the platforms have quietly diverged.
struct SideMenuDestinationTests {
    @Test
    func holdsExactlyTheFourSecondarySurfacesInOrder() {
        #expect(SideMenuDestination.allCases.map(\.title) == [
            "Settings",
            "Lists",
            "Activity",
            "Year in Review",
        ])
    }

    @Test
    func everyDestinationHasAnIcon() {
        for destination in SideMenuDestination.allCases {
            #expect(!destination.systemImage.isEmpty)
        }
    }

    @Test
    func idsAreStableAndDistinct() {
        // The panel renders these with ForEach, so a collision would drop a row.
        let ids = Set(SideMenuDestination.allCases.map(\.id))
        #expect(ids.count == SideMenuDestination.allCases.count)
    }
}

/// The kind labels the filter chips use, which have to match web's.
struct MediaKindPluralTests {
    @Test
    func pluralLabelsMatchWeb() {
        #expect(MediaKind.movie.pluralDisplayName == "Movies")
        #expect(MediaKind.show.pluralDisplayName == "Shows")
        #expect(MediaKind.book.pluralDisplayName == "Books")
        #expect(MediaKind.album.pluralDisplayName == "Albums")
    }

    @Test
    func everyKindHasAPluralLabel() {
        // CaseIterable, so a kind added later fails here rather than
        // rendering an empty chip.
        for kind in MediaKind.allCases {
            #expect(!kind.pluralDisplayName.isEmpty)
        }
    }
}

/// The three primary tabs. Lists and Activity moved to the side menu.
struct MainTabTests {
    @Test
    func onlyThePrimarySurfacesAreTabs() {
        #expect(MainTab.allCases == [.feed, .explorer, .profile])
    }

    @Test
    func swipeOrderRunsEndToEnd() {
        // `next`/`previous` drive the swipe gesture; a gap would strand a tab.
        #expect(MainTab.feed.previous == nil)
        #expect(MainTab.feed.next == .explorer)
        #expect(MainTab.explorer.next == .profile)
        #expect(MainTab.profile.next == nil)
        #expect(MainTab.profile.previous == .explorer)
    }
}
