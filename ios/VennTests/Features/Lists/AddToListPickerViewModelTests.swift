import Foundation
import Testing
@testable import Venn

/// The post-log "also add to a list" picker.
@MainActor
struct AddToListPickerViewModelTests {
    @Test
    func loadsTheOwnersLists() async {
        let service = FakeListsService(lists: [Self.list(title: "Best of 2026")])
        let viewModel = AddToListPickerViewModel(
            ownerID: Self.ownerID,
            mediaID: Self.mediaID,
            service: service
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded(service.seeded))
        #expect(service.listedOwners == [Self.ownerID])
    }

    @Test
    func mapsALoadFailureToTheSharedErrorReason() async {
        let service = FakeListsService(lists: [])
        service.error = AppError.network
        let viewModel = AddToListPickerViewModel(
            ownerID: Self.ownerID,
            mediaID: Self.mediaID,
            service: service
        )

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func appendsAtTheEndOfTheList() async {
        // Position is read fresh rather than tracked, so a second device
        // adding at the same time doesn't claim the same slot.
        let list = Self.list(title: "Best of 2026")
        let service = FakeListsService(lists: [list])
        service.itemPositions = [0, 1, 2]
        let viewModel = AddToListPickerViewModel(
            ownerID: Self.ownerID,
            mediaID: Self.mediaID,
            service: service
        )
        await viewModel.load()

        await viewModel.add(to: list)

        #expect(service.addedPositions == [3])
        #expect(viewModel.added.contains(list.id))
    }

    @Test
    func firstItemInAnEmptyListGoesToPositionZero() async {
        let list = Self.list(title: "Empty")
        let service = FakeListsService(lists: [list])
        let viewModel = AddToListPickerViewModel(
            ownerID: Self.ownerID,
            mediaID: Self.mediaID,
            service: service
        )
        await viewModel.load()

        await viewModel.add(to: list)

        #expect(service.addedPositions == [0])
    }

    @Test
    func addingTwiceToTheSameListIsOneWrite() async {
        // The row disables itself once added; this makes sure the model
        // enforces it too rather than trusting the view.
        let list = Self.list(title: "Best of 2026")
        let service = FakeListsService(lists: [list])
        let viewModel = AddToListPickerViewModel(
            ownerID: Self.ownerID,
            mediaID: Self.mediaID,
            service: service
        )
        await viewModel.load()

        await viewModel.add(to: list)
        await viewModel.add(to: list)

        #expect(service.addedPositions.count == 1)
    }

    @Test
    func aFailedAddSurfacesAMessageAndLeavesTheRowAddable() async {
        let list = Self.list(title: "Best of 2026")
        let service = FakeListsService(lists: [list])
        let viewModel = AddToListPickerViewModel(
            ownerID: Self.ownerID,
            mediaID: Self.mediaID,
            service: service
        )
        await viewModel.load()
        service.error = AppError.network

        await viewModel.add(to: list)

        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.added.contains(list.id))
        #expect(viewModel.working == nil)
    }

    // MARK: - Fixtures

    private static let ownerID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    ) ?? UUID()
    private static let mediaID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    ) ?? UUID()

    private static func list(title: String) -> UserList {
        UserList(
            id: UUID(),
            ownerID: ownerID,
            title: title,
            description: nil,
            isPublic: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

/// Records what was written so tests can assert positions without a
/// database. Set `error` to fail the next call.
final class FakeListsService: ListServicing, @unchecked Sendable {
    /// Not named `lists`: the protocol requires a `lists(ownerID:)` method,
    /// and a property sharing that base name makes every reference resolve
    /// to the throwing function instead of the array.
    let seeded: [UserList]
    /// Positions the fake reports as already occupied.
    var itemPositions: [Int] = []
    var error: AppError?
    private(set) var listedOwners: [UUID] = []
    private(set) var addedPositions: [Int] = []
    private(set) var removed: [UUID] = []

    init(lists: [UserList]) {
        seeded = lists
    }

    func lists(ownerID: UUID) async throws -> [UserList] {
        listedOwners.append(ownerID)
        if let error {
            throw error
        }
        return seeded
    }

    func list(id _: UUID) async throws -> UserList? {
        seeded.first
    }

    func items(listID _: UUID) async throws -> [ListItem] {
        if let error {
            throw error
        }
        return itemPositions.map { position in
            ListItem(
                media: Media(
                    id: UUID(),
                    kind: .movie,
                    title: "Existing \(position)",
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
    }

    func createList(
        ownerID _: UUID,
        title _: String,
        description _: String?,
        isPublic _: Bool
    ) async throws -> UUID {
        UUID()
    }

    func deleteList(id _: UUID) async throws {}

    func addItem(listID _: UUID, mediaID _: UUID, position: Int, note _: String?) async throws {
        if let error {
            throw error
        }
        addedPositions.append(position)
    }

    func removeItem(listID _: UUID, mediaID: UUID) async throws {
        removed.append(mediaID)
    }
}
