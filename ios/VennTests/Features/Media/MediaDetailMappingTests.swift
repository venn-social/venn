import Foundation
import Testing
@testable import Venn

/// Provider → `MediaDetail` mapping. The three catalogs disagree about
/// almost everything they hold, and this is where that disagreement gets
/// normalised — so it's where the bugs live. Mirrors web's
/// `web/lib/catalog/__tests__/detail.test.ts` case for case (rule 17).
struct MediaDetailMappingTests {
    // MARK: - TMDB

    private static let movie = TMDBDetailResponse(
        overview: "Two friends reunite.",
        runtime: 106,
        episodeRunTime: nil,
        genres: [TMDBGenre(name: "Drama"), TMDBGenre(name: "Romance")],
        releaseDate: "2023-06-02",
        firstAirDate: nil,
        voteAverage: 7.8,
        credits: TMDBCredits(
            cast: [TMDBPerson(name: "Greta Lee", character: "Nora", job: nil)],
            crew: [
                TMDBPerson(name: "Celine Song", character: nil, job: "Director"),
                TMDBPerson(name: "Someone Else", character: nil, job: "Gaffer"),
            ]
        ),
        createdBy: nil,
        watchProviders: TMDBWatchProviders(results: [
            "GB": TMDBRegionProviders(
                link: "https://tmdb.example/watch",
                flatrate: [TMDBProviderEntry(providerName: "Netflix", logoPath: "/n.jpg")],
                rent: [
                    TMDBProviderEntry(providerName: "Netflix", logoPath: nil),
                    TMDBProviderEntry(providerName: "Apple TV", logoPath: nil),
                ],
                buy: nil
            ),
            "US": TMDBRegionProviders(
                link: nil,
                flatrate: [TMDBProviderEntry(providerName: "Hulu", logoPath: nil)],
                rent: nil,
                buy: nil
            ),
        ])
    )

    @Test
    func mapsTheRecordCastAndDirector() {
        let detail = TMDBDetail.detail(from: Self.movie, region: "GB")

        #expect(detail.overview == "Two friends reunite.")
        #expect(detail.runtime == 106)
        #expect(detail.genres == ["Drama", "Romance"])
        #expect(detail.credits.first == Credit(name: "Greta Lee", role: "Nora"))
        #expect(detail.creators.map(\.name) == ["Celine Song"])
    }

    @Test
    func keepsOnlyTheCrewCreditThatAnswersWhoMadeThis() {
        // A full crew list runs to hundreds of names; the gaffer isn't the
        // answer anyone is looking for on a detail page.
        #expect(TMDBDetail.detail(from: Self.movie, region: "GB").creators.count == 1)
    }

    @Test
    func returnsAvailabilityForTheRequestedRegionOnly() {
        let detail = TMDBDetail.detail(from: Self.movie, region: "GB")

        #expect(detail.watchLinks.map(\.provider) == ["Netflix", "Apple TV"])
        #expect(detail.watchRegion == "GB")
    }

    @Test
    func listsAProviderOnceUnderTheCheapestWayToWatch() {
        // Netflix appears under both flatrate and rent here. Streaming is
        // the useful answer; showing it twice implies you must pay.
        let netflix = TMDBDetail.detail(from: Self.movie, region: "GB")
            .watchLinks
            .filter { $0.provider == "Netflix" }

        #expect(netflix.count == 1)
        #expect(netflix.first?.kind == .stream)
    }

    @Test
    func returnsNoLinksForARegionWithNoAvailability() {
        #expect(TMDBDetail.detail(from: Self.movie, region: "JP").watchLinks.isEmpty)
    }

    @Test
    func survivesAnEmptyPayload() {
        let empty = TMDBDetailResponse(
            overview: nil,
            runtime: nil,
            episodeRunTime: nil,
            genres: nil,
            releaseDate: nil,
            firstAirDate: nil,
            voteAverage: nil,
            credits: nil,
            createdBy: nil,
            watchProviders: nil
        )
        let detail = TMDBDetail.detail(from: empty, region: "GB")

        #expect(detail.overview == nil)
        #expect(detail.credits.isEmpty)
        #expect(detail.watchLinks.isEmpty)
    }

    @Test
    func fallsBackToShowFieldsForTelevision() {
        // TMDB names the same facts differently for TV: episode_run_time
        // and first_air_date rather than runtime and release_date.
        let show = TMDBDetailResponse(
            overview: nil,
            runtime: nil,
            episodeRunTime: [52],
            genres: nil,
            releaseDate: nil,
            firstAirDate: "2019-05-19",
            voteAverage: nil,
            credits: nil,
            createdBy: [TMDBPerson(name: "Phoebe Waller-Bridge", character: nil, job: nil)],
            watchProviders: nil
        )
        let detail = TMDBDetail.detail(from: show, region: "GB")

        #expect(detail.runtime == 52)
        #expect(detail.releaseDate == "2019-05-19")
        #expect(detail.creators.first?.name == "Phoebe Waller-Bridge")
    }

    // MARK: - OpenLibrary

    @Test
    func mapsABookDescriptionAndAuthor() {
        let work = OLWork(
            description: .text("A house of halls."),
            subjects: nil,
            firstPublishDate: "2020-09-15",
            authors: nil
        )
        let detail = OpenLibraryDetail.detail(from: work, authorNames: ["Susanna Clarke"])

        #expect(detail.overview == "A house of halls.")
        #expect(detail.creators == [Credit(name: "Susanna Clarke", role: "Author")])
        #expect(detail.releaseDate == "2020-09-15")
    }

    @Test
    func acceptsADescriptionGivenAsABareString() throws {
        // Older OpenLibrary records use the string form rather than an object.
        let json = Data(#"{"description": "Plain text."}"#.utf8)
        let work = try JSONDecoder().decode(OLWork.self, from: json)

        #expect(OpenLibraryDetail.detail(from: work, authorNames: []).overview == "Plain text.")
    }

    @Test
    func acceptsADescriptionGivenAsAnObject() throws {
        let json = Data(#"{"description": {"value": "Wrapped."}}"#.utf8)
        let work = try JSONDecoder().decode(OLWork.self, from: json)

        #expect(OpenLibraryDetail.detail(from: work, authorNames: []).overview == "Wrapped.")
    }

    @Test
    func capsTheSubjectListSinceRecordsCarryDozens() {
        let work = OLWork(
            description: nil,
            subjects: (0..<30).map { "Subject \($0)" },
            firstPublishDate: nil,
            authors: nil
        )

        #expect(OpenLibraryDetail.detail(from: work, authorNames: []).genres.count == 8)
    }

    // MARK: - MusicBrainz

    @Test
    func mapsTheArtistAndOrdersTagsByHowManyPeopleAppliedThem() {
        let response = MBDetailResponse(
            artistCredit: [MBArtistCreditEntry(name: nil, artist: MBArtist(name: "Radiohead"))],
            firstReleaseDate: "2016-05-08",
            tags: [MBTag(name: "rock", count: 2), MBTag(name: "art rock", count: 9)]
        )
        let detail = MusicBrainzDetail.detail(from: response)

        #expect(detail.creators == [Credit(name: "Radiohead", role: "Artist")])
        #expect(detail.genres == ["art rock", "rock"])
        #expect(detail.releaseDate == "2016-05-08")
    }

    @Test
    func leavesTheAlbumDescriptionNilRatherThanInventingOne() {
        // MusicBrainz is a structured database, not a review site.
        let response = MBDetailResponse(
            artistCredit: [MBArtistCreditEntry(name: nil, artist: MBArtist(name: "X"))],
            firstReleaseDate: nil,
            tags: nil
        )

        #expect(MusicBrainzDetail.detail(from: response).overview == nil)
    }

    // MARK: - Formatting

    @Test(arguments: [
        (0, String?.none),
        (45, "45m"),
        (60, "1h"),
        (106, "1h 46m"),
        (137, "2h 17m"),
    ])
    func formatsRuntimeAsHoursAndMinutes(minutes: Int, expected: String?) {
        var detail = MediaDetail()
        detail.runtime = minutes

        #expect(detail.formattedRuntime == expected)
    }

    @Test
    func hasNoRuntimeWhenTheProviderDidNotSupplyOne() {
        #expect(MediaDetail.empty.formattedRuntime == nil)
    }

    // MARK: - Source links

    @Test
    func linksAMovieAndAShowToTheirDifferentTMDBPaths() {
        #expect(
            MediaDetailService.sourceURL(source: .tmdb, kind: .movie, externalID: "1")
                == URL(string: "https://www.themoviedb.org/movie/1")
        )
        #expect(
            MediaDetailService.sourceURL(source: .tmdb, kind: .show, externalID: "1")
                == URL(string: "https://www.themoviedb.org/tv/1")
        )
    }

    @Test
    func linksBooksAndAlbumsToTheirOwnCatalogs() {
        #expect(
            MediaDetailService.sourceURL(source: .openlibrary, kind: .book, externalID: "OL1W")
                == URL(string: "https://openlibrary.org/works/OL1W")
        )
        #expect(
            MediaDetailService.sourceURL(source: .musicbrainz, kind: .album, externalID: "mbid")
                == URL(string: "https://musicbrainz.org/release-group/mbid")
        )
    }
}
