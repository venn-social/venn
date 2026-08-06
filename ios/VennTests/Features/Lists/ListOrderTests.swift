import Foundation
import Testing
@testable import Venn

/// The move rules. Mirrors web's `listOrder.test.ts` case for case — the
/// two must agree or a list reordered on one platform would look different
/// on the other.
struct ListOrderTests {
    private static func item(_ index: Int, position: Int) -> ListItem {
        ListItem(
            media: Media(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))
                    ?? UUID(),
                kind: .movie,
                title: "Title \(index)",
                year: nil,
                primaryCreator: nil,
                coverURL: nil,
                externalID: nil,
                externalSource: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            position: position,
            note: nil
        )
    }

    private static let items = [item(1, position: 0), item(2, position: 1), item(3, position: 2)]
    private static var ids: [UUID] {
        items.map(\.media.id)
    }

    @Test
    func movesAnItemUpOnePlace() {
        let moved = ListOrder.moved(Self.items, mediaID: Self.ids[1], direction: .up)
        #expect(moved == [Self.ids[1], Self.ids[0], Self.ids[2]])
    }

    @Test
    func movesAnItemDownOnePlace() {
        let moved = ListOrder.moved(Self.items, mediaID: Self.ids[1], direction: .down)
        #expect(moved == [Self.ids[0], Self.ids[2], Self.ids[1]])
    }

    @Test
    func leavesTheFirstItemAloneWhenAskedToMoveItUp() {
        // The control is hidden at the ends, but the rule belongs here too —
        // a wrap-around would silently reorder the whole list.
        #expect(ListOrder.moved(Self.items, mediaID: Self.ids[0], direction: .up) == Self.ids)
    }

    @Test
    func leavesTheLastItemAloneWhenAskedToMoveItDown() {
        #expect(ListOrder.moved(Self.items, mediaID: Self.ids[2], direction: .down) == Self.ids)
    }

    @Test
    func ignoresAnIDThatIsNotInTheList() {
        #expect(ListOrder.moved(Self.items, mediaID: UUID(), direction: .up) == Self.ids)
    }

    @Test
    func returnsTheFullOrderNotJustThePairThatMoved() {
        // The RPC rewrites every position from this array, so a partial
        // answer would blank the rest of the list.
        #expect(ListOrder.moved(Self.items, mediaID: Self.ids[2], direction: .up).count == 3)
    }

    @Test
    func handlesASingleItemListWithoutMovingAnything() {
        let single = [Self.item(9, position: 0)]
        let onlyID = single[0].media.id
        #expect(ListOrder.moved(single, mediaID: onlyID, direction: .down) == [onlyID])
    }
}

@MainActor
struct ListDetailReorderTests {
    @Test
    func aMoveShowsImmediatelyAndPersistsTheWholeOrder() async {
        let service = FakeListsService(lists: [])
        service.itemPositions = [0, 1, 2]
        let viewModel = ListDetailViewModel(listID: UUID(), service: service)
        await viewModel.load()

        guard case let .loaded(items) = viewModel.state, items.count == 3 else {
            Issue.record("expected three loaded items")
            return
        }
        await viewModel.move(mediaID: items[2].media.id, direction: .up)

        guard case let .loaded(after) = viewModel.state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(after.map(\.media.id) == [items[0].media.id, items[2].media.id, items[1].media.id])
        #expect(service.reordered.count == 1)
        #expect(service.reordered[0].count == 3)
    }

    @Test
    func aMoveThatWouldFallOffTheEndIsNotAWrite() async {
        let service = FakeListsService(lists: [])
        service.itemPositions = [0, 1]
        let viewModel = ListDetailViewModel(listID: UUID(), service: service)
        await viewModel.load()

        guard case let .loaded(items) = viewModel.state, let first = items.first else {
            Issue.record("expected loaded items")
            return
        }
        await viewModel.move(mediaID: first.media.id, direction: .up)

        #expect(service.reordered.isEmpty)
    }
}
