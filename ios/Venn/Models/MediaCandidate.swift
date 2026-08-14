import Foundation

/// A search result from an external media catalog API (TMDB, OpenLibrary,
/// MusicBrainz) before the item is persisted to `public.media`.
///
/// The post composer presents these to the user for selection. Once the
/// user confirms a pick, the composer service upserts the candidate into
/// Supabase — idempotent on `(external_source, external_id)` — before
/// creating the post row.
struct MediaCandidate: Equatable, Identifiable {
    /// `"<source>:<kind>:<externalId>"`, byte-identical to web's
    /// `candidateId()`. Kind is load-bearing: TMDB numbers movies and TV
    /// independently, so movie 123 and show 123 are different things that
    /// would otherwise collide. Recommendations compare this key across
    /// platforms to filter out what you have already seen.
    var id: String {
        "\(externalSource.rawValue):\(kind.rawValue):\(externalID)"
    }

    let title: String
    let primaryCreator: String?
    let year: Int?
    let coverURL: URL?
    /// Plot/description text. Populated from TMDB `overview` or OpenLibrary
    /// `first_sentence`. Nil for music (MusicBrainz doesn't surface descriptions).
    let overview: String?
    let externalID: String
    let externalSource: ExternalSource
    let kind: MediaKind
}

extension MediaCandidate {
    /// A copy crediting a different name, used when the search result's
    /// author is written in a script the reader cannot read and the author
    /// record offers a Latin form.
    func replacingPrimaryCreator(_ creator: String) -> MediaCandidate {
        MediaCandidate(
            title: title,
            primaryCreator: creator,
            year: year,
            coverURL: coverURL,
            overview: overview,
            externalID: externalID,
            externalSource: externalSource,
            kind: kind
        )
    }
}
