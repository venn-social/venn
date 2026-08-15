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
            "Last 12 Months",
        ])
    }

    @Test
    func doesNotPromiseACalendarYear() {
        // personal_stats_monthly() returns the trailing twelve months. The
        // accessibility label always said so; the visible heading used to
        // say "Year in Review", which is a different thing entirely and the
        // sort of claim nobody re-reads once it ships.
        let titles = SideMenuDestination.allCases.map(\.title)
        #expect(!titles.contains { $0.localizedCaseInsensitiveContains("year") })
        #expect(titles.contains("Last 12 Months"))
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
