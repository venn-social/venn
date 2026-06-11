import Testing
@testable import Venn

/// Invariants the Explorer view relies on when routing a query to the
/// media search vs the people search.
struct ExplorerCategoryTests {
    @Test
    func peopleSearchesNoMediaKinds() {
        #expect(ExplorerCategory.people.searchKinds.isEmpty)
    }

    @Test
    func peopleHasNoBrowseKind() {
        #expect(ExplorerCategory.people.browseKind == nil)
    }

    @Test
    func everyMediaCategorySearchesAtLeastOneKind() {
        for category in ExplorerCategory.allCases where category != .people {
            #expect(!category.searchKinds.isEmpty)
        }
    }

    @Test
    func allCategorySearchesEveryKind() {
        #expect(Set(ExplorerCategory.all.searchKinds) == Set(MediaKind.allCases))
    }

    @Test
    func everyCategoryHasAChipTitleAndIcon() {
        // The segmented control renders these directly — a new category
        // without them would ship a blank chip.
        for category in ExplorerCategory.allCases {
            #expect(!category.title.isEmpty)
            #expect(!category.icon.isEmpty)
        }
    }
}
