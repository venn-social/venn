import Foundation

/// One title from an export, merged across its files, ready to match.
struct ImportEntry: Equatable {
    let kind: MediaKind
    /// Sanitized; used as the catalog search query, never stored.
    let title: String
    let year: Int?
    /// Author for books — narrows the match.
    let creator: String?
    /// ISBN-13 or ISBN-10 when the export has one — the strongest match key.
    let isbn: String?
    let action: PostAction
    let rating: Double?
    /// "YYYY-MM-DD" from the export; the imported post is dated to it.
    let consumedAt: String?
}

/// A row that could not be turned into an entry at all.
struct ImportRowProblem: Equatable {
    enum Reason: Equatable {
        case missingTitle
        case titleTooLong
        /// A Goodreads exclusive shelf other than read, to-read or
        /// currently-reading (e.g. "did-not-finish"), whose meaning venn
        /// cannot represent without guessing.
        case unsupportedShelf
    }

    let file: String
    /// 1-based line in the file, counting the header as line 1.
    let line: Int
    let reason: Reason
}

/// What a parser produced from an export.
struct ParsedExport: Equatable {
    let entries: [ImportEntry]
    let problems: [ImportRowProblem]
}

/// What an import did, for the screen that will eventually show it.
struct ImportReport: Equatable {
    let imported: Int
    /// Already in the person's venn library; left untouched.
    let alreadyInLibrary: Int
    /// Nothing in the catalog matched these.
    let unmatched: [ImportEntry]
    let problems: [ImportRowProblem]
}

/// One element of `import_library`'s `_items` argument. Field names match
/// web's `ImportItem` exactly, because both send them to the same RPC.
struct ImportItem: Encodable, Equatable {
    let kind: String
    let title: String
    let year: Int?
    let primaryCreator: String?
    let coverUrl: String?
    let externalSource: String
    let externalId: String
    let action: String
    let rating: Double?
    let consumedAt: String?

    enum CodingKeys: String, CodingKey {
        case kind, title, year, action, rating
        case primaryCreator = "primary_creator"
        case coverUrl = "cover_url"
        case externalSource = "external_source"
        case externalId = "external_id"
        case consumedAt = "consumed_at"
    }

    /// Catalog fields from the match; the opinion and date from the export.
    init(entry: ImportEntry, candidate: MediaCandidate) {
        kind = candidate.kind.rawValue
        title = candidate.title
        year = candidate.year
        primaryCreator = candidate.primaryCreator
        coverUrl = candidate.coverURL?.absoluteString
        externalSource = candidate.externalSource.rawValue
        externalId = candidate.externalID
        action = entry.action.rawValue
        rating = entry.rating
        consumedAt = entry.consumedAt
    }

    /// Explicit so nil fields go over the wire as null rather than being
    /// dropped — the RPC reads every key.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(year, forKey: .year)
        try container.encode(primaryCreator, forKey: .primaryCreator)
        try container.encode(coverUrl, forKey: .coverUrl)
        try container.encode(externalSource, forKey: .externalSource)
        try container.encode(externalId, forKey: .externalId)
        try container.encode(action, forKey: .action)
        try container.encode(rating, forKey: .rating)
        try container.encode(consumedAt, forKey: .consumedAt)
    }
}

/// `import_library`'s answer for one batch.
struct ImportWriteResult: Decodable, Equatable {
    let imported: Int
    let skipped: Int
}
