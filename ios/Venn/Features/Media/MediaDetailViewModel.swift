import Foundation
import Observation

/// Drives `MediaDetailView` — the enriched record for one catalog item.
///
/// Only the *enrichment* goes through `state`. The title, cover, year, and
/// creator come from our own `media` row and are on screen before this
/// model runs, so a provider being unreachable thins the page instead of
/// replacing it. That's why `media` is held here rather than being part of
/// the loaded value.
@MainActor
@Observable
final class MediaDetailViewModel {
    typealias State = LoadState<MediaDetail>

    let media: Media
    private(set) var state: State = .loading

    private let service: any MediaDetailServicing
    private let region: String

    /// - Parameter region: ISO country for watch availability. Defaults to
    ///   the device's — iOS knows this directly, which beats anything a
    ///   server can infer from an IP.
    init(
        media: Media,
        service: any MediaDetailServicing,
        region: String = WatchRegion.current
    ) {
        self.media = media
        self.service = service
        self.region = region
    }

    func load() async {
        state = .loading
        do {
            state = try await .loaded(service.detail(for: media, region: region))
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// The composer needs a candidate, not a `Media`. Nil for a hand-typed
    /// row: with no external identity there's nothing for the composer to
    /// de-duplicate against.
    var logCandidate: MediaCandidate? {
        guard let externalID = media.externalID, let externalSource = media.externalSource else {
            return nil
        }
        return MediaCandidate(
            title: media.title,
            primaryCreator: media.primaryCreator,
            year: media.year,
            coverURL: media.coverURL,
            overview: loadedDetail?.overview,
            externalID: externalID,
            externalSource: externalSource,
            kind: media.kind
        )
    }

    private var loadedDetail: MediaDetail? {
        if case let .loaded(detail) = state {
            return detail
        }
        return nil
    }
}
