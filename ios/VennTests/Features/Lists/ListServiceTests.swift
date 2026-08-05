import Foundation
import Testing
@testable import Venn

@Suite("ListService wire formats")
struct ListServiceTests {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test("decodes a list row")
    func decodesListRow() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "title": "Best of 2026",
          "description": "So far.",
          "is_public": true,
          "created_at": "2026-08-01T00:00:00Z",
          "updated_at": "2026-08-05T00:00:00Z"
        }
        """
        let list = try UserList(row: Self.decoder.decode(ListRow.self, from: Data(json.utf8)))

        #expect(list.title == "Best of 2026")
        #expect(list.isPublic == true)
        #expect(list.description == "So far.")
    }

    @Test("decodes a private list with no description")
    func decodesSparseListRow() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "title": "Untitled",
          "description": null,
          "is_public": false,
          "created_at": "2026-08-01T00:00:00Z",
          "updated_at": "2026-08-01T00:00:00Z"
        }
        """
        let list = try UserList(row: Self.decoder.decode(ListRow.self, from: Data(json.utf8)))

        #expect(list.description == nil)
        #expect(list.isPublic == false)
    }

    @Test("lifts a list item, keeping its position and note")
    func liftsListItem() throws {
        let json = """
        {
          "position": 2,
          "note": "The ending.",
          "media": {
            "id": "33333333-3333-3333-3333-333333333333",
            "kind": "movie",
            "title": "Past Lives",
            "year": 2023,
            "primary_creator": "Celine Song",
            "cover_url": null,
            "external_id": null,
            "external_source": null,
            "created_at": "2026-01-01T00:00:00Z"
          }
        }
        """
        let row = try Self.decoder.decode(ListItemRow.self, from: Data(json.utf8))
        let item = try #require(ListItem(row: row))

        #expect(item.media.title == "Past Lives")
        #expect(item.position == 2)
        #expect(item.note == "The ending.")
    }

    @Test("drops an item whose media kind is unknown")
    func dropsUnknownKind() throws {
        // Forwards-compat: a new media kind shipped server-side must not
        // break an already-deployed client.
        let json = """
        {
          "position": 0,
          "note": null,
          "media": {
            "id": "33333333-3333-3333-3333-333333333333",
            "kind": "hologram",
            "title": "Weird",
            "year": null,
            "primary_creator": null,
            "cover_url": null,
            "external_id": null,
            "external_source": null,
            "created_at": "2026-01-01T00:00:00Z"
          }
        }
        """
        let row = try Self.decoder.decode(ListItemRow.self, from: Data(json.utf8))

        #expect(ListItem(row: row) == nil)
    }
}

@Suite("nextListPosition")
struct NextListPositionTests {
    private func item(at position: Int) -> ListItem {
        ListItem(
            media: Media(
                id: UUID(),
                kind: .movie,
                title: "T",
                year: nil,
                primaryCreator: nil,
                coverURL: nil,
                externalID: nil,
                externalSource: nil,
                createdAt: Date()
            ),
            position: position,
            note: nil
        )
    }

    @Test("starts at zero for an empty list")
    func emptyList() {
        #expect(nextListPosition([]) == 0)
    }

    @Test("appends after the highest position")
    func appendsAfterHighest() {
        #expect(nextListPosition([item(at: 0), item(at: 1)]) == 2)
    }

    @Test("does not collide after an item is removed from the middle")
    func survivesGaps() {
        // Counting items would return 2 here — which position 2 already holds.
        #expect(nextListPosition([item(at: 0), item(at: 2)]) == 3)
    }
}
