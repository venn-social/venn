import Foundation
import Supabase

/// A user-curated list. Distinct from the Collection and Watchlist shelves,
/// which are *derived* from what you logged — a list is *authored*, and its
/// order is a statement.
struct UserList: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let title: String
    let description: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
}

/// One entry in a list. `position` is explicit rather than derived from
/// insertion time, because the maker's ordering is the point.
struct ListItem: Identifiable, Equatable, Sendable {
    let media: Media
    let position: Int
    let note: String?

    var id: UUID {
        media.id
    }
}

/// Lists read/write surface. Behind a protocol so view-models unit-test
/// with a fake (ADR 0005).
///
/// Visibility is entirely RLS's job: a private list simply doesn't come
/// back for anyone but its owner, so none of these methods filter on
/// `is_public` — duplicating the rule client-side is how the two drift.
protocol ListServicing: Sendable {
    func lists(ownerID: UUID) async throws -> [UserList]
    func list(id: UUID) async throws -> UserList?
    func items(listID: UUID) async throws -> [ListItem]
    func createList(ownerID: UUID, title: String, description: String?, isPublic: Bool) async throws -> UUID
    func deleteList(id: UUID) async throws
    func addItem(listID: UUID, mediaID: UUID, position: Int, note: String?) async throws
    func removeItem(listID: UUID, mediaID: UUID) async throws

    /// Rewrite the whole order.
    ///
    /// Sends every id rather than a swap: the RPC applies it in one
    /// statement, so a failure cannot leave two items claiming the same
    /// slot, and a list whose positions have already drifted comes back
    /// consistent.
    func reorder(listID: UUID, mediaIDs: [UUID]) async throws
}

/// The order that results from moving one item a single place.
///
/// Pure, so the rules are testable without a database and the view can
/// render the new order before the write lands. Returns the input unchanged
/// when the move would fall off either end. Mirrors web's `movedOrder`.
enum ListOrder {
    enum Direction {
        case up, down
    }

    static func moved(_ items: [ListItem], mediaID: UUID, direction: Direction) -> [UUID] {
        let ids = items.map(\.media.id)
        guard let from = ids.firstIndex(of: mediaID) else { return ids }

        let to = direction == .up ? from - 1 : from + 1
        guard to >= 0, to < ids.count else { return ids }

        var next = ids
        next.swapAt(from, to)
        return next
    }
}

struct ListService: ListServicing {
    let client: SupabaseClient

    func lists(ownerID: UUID) async throws -> [UserList] {
        do {
            let rows: [ListRow] = try await client
                .from("lists")
                .select("*")
                .eq("owner_id", value: ownerID)
                .order("updated_at", ascending: false)
                .execute()
                .value
            return rows.map(UserList.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }

    func list(id: UUID) async throws -> UserList? {
        do {
            let rows: [ListRow] = try await client
                .from("lists")
                .select("*")
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value
            return rows.first.map(UserList.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }

    func items(listID: UUID) async throws -> [ListItem] {
        do {
            let rows: [ListItemRow] = try await client
                .from("list_items")
                .select("position, note, media(*)")
                .eq("list_id", value: listID)
                .order("position", ascending: true)
                .execute()
                .value
            return rows.compactMap(ListItem.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }

    func createList(
        ownerID: UUID,
        title: String,
        description: String?,
        isPublic: Bool
    ) async throws -> UUID {
        do {
            let rows: [ListIDRow] = try await client
                .from("lists")
                .insert(
                    ListInsert(
                        ownerId: ownerID,
                        title: title,
                        description: description,
                        isPublic: isPublic
                    )
                )
                .select("id")
                .execute()
                .value
            guard let id = rows.first?.id else {
                throw AppError.unknown(message: "List insert returned no id")
            }
            return id
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.from(error)
        }
    }

    func deleteList(id: UUID) async throws {
        do {
            try await client.from("lists").delete().eq("id", value: id).execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func addItem(listID: UUID, mediaID: UUID, position: Int, note: String?) async throws {
        do {
            try await client
                .from("list_items")
                .upsert(
                    ListItemInsert(
                        listId: listID,
                        mediaId: mediaID,
                        position: position,
                        note: note
                    ),
                    onConflict: "list_id,media_id"
                )
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func reorder(listID: UUID, mediaIDs: [UUID]) async throws {
        do {
            try await client
                .rpc("reorder_list_items", params: [
                    "_list_id": AnyJSON.string(listID.uuidString),
                    "_media_ids": AnyJSON.array(mediaIDs.map { .string($0.uuidString) }),
                ])
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func removeItem(listID: UUID, mediaID: UUID) async throws {
        do {
            try await client
                .from("list_items")
                .delete()
                .eq("list_id", value: listID)
                .eq("media_id", value: mediaID)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }
}

/// Where the next appended item goes. Derived from the highest existing
/// position rather than the item count: removing from the middle leaves a
/// gap, and counting would then hand out a position already taken.
func nextListPosition(_ items: [ListItem]) -> Int {
    (items.map(\.position).max() ?? -1) + 1
}

// MARK: - Wire formats

struct ListRow: Decodable, Equatable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let description: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case ownerId = "owner_id"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ListItemRow: Decodable, Equatable {
    let position: Int
    let note: String?
    let media: MediaSchema.Row
}

private struct ListIDRow: Decodable {
    let id: UUID
}

private struct ListInsert: Encodable {
    let ownerId: UUID
    let title: String
    let description: String?
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case title, description
        case ownerId = "owner_id"
        case isPublic = "is_public"
    }
}

private struct ListItemInsert: Encodable {
    let listId: UUID
    let mediaId: UUID
    let position: Int
    let note: String?

    enum CodingKeys: String, CodingKey {
        case position, note
        case listId = "list_id"
        case mediaId = "media_id"
    }
}

extension UserList {
    init(row: ListRow) {
        id = row.id
        ownerID = row.ownerId
        title = row.title
        description = row.description
        isPublic = row.isPublic
        createdAt = row.createdAt
        updatedAt = row.updatedAt
    }
}

extension ListItem {
    /// Nil when the media kind is one this client doesn't know — same
    /// forwards-compatibility rule the feed uses.
    init?(row: ListItemRow) {
        guard let media = Media(row: row.media) else { return nil }
        self.media = media
        position = row.position
        note = row.note
    }
}
