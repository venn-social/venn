/**
 * Trimmed catalog responses in the providers' real shapes, for the mapper
 * tests and the dry run. Titles, dates and credits follow the real records;
 * some ids are illustrative, and fields the mappers ignore are left out.
 */

/** TMDB /movie/666277?append_to_response=credits,keywords — Past Lives. */
export const TMDB_PAST_LIVES = {
  id: 666277,
  title: "Past Lives",
  release_date: "2023-06-02",
  runtime: 106,
  original_language: "en",
  production_countries: [{ iso_3166_1: "US" }, { iso_3166_1: "KR" }],
  genres: [
    { id: 18, name: "Drama" },
    { id: 10749, name: "Romance" }
  ],
  keywords: {
    keywords: [{ name: "coming of age" }, { name: "new york city" }, { name: "Film Noir" }]
  },
  credits: {
    cast: [
      { id: 1120526, name: "Teo Yoo", order: 1 },
      { id: 1253360, name: "Greta Lee", order: 0 },
      { id: 18999, name: "John Magaro", order: 2 },
      { id: 1, name: "Extra Four", order: 3 },
      { id: 2, name: "Extra Five", order: 4 },
      { id: 3, name: "Extra Six", order: 5 }
    ],
    crew: [
      { id: 2340979, name: "Celine Song", job: "Director" },
      { id: 2340979, name: "Celine Song", job: "Writer" },
      { id: 2340979, name: "Celine Song", job: "Screenplay" },
      { id: 1500, name: "Christopher Bear", job: "Original Music Composer" },
      { id: 1501, name: "Some Grip", job: "Key Grip" }
    ]
  }
};

/** TMDB /tv/1396?append_to_response=credits,keywords — Breaking Bad. */
export const TMDB_BREAKING_BAD = {
  id: 1396,
  name: "Breaking Bad",
  first_air_date: "2008-01-20",
  episode_run_time: [45, 47],
  number_of_episodes: 62,
  original_language: "en",
  origin_country: ["US"],
  genres: [
    { id: 18, name: "Drama" },
    { id: 80, name: "Crime" }
  ],
  keywords: { results: [{ name: "drug dealer" }, { name: "neo-noir" }] },
  created_by: [{ id: 66633, name: "Vince Gilligan" }],
  credits: { cast: [{ id: 17419, name: "Bryan Cranston", order: 0 }], crew: [] }
};

/** Open Library search.json doc for /works/OL20893680W — Klara and the Sun. */
export const OL_KLARA = {
  key: "/works/OL20893680W",
  first_publish_year: 2021,
  number_of_pages_median: 303,
  language: ["eng"],
  subject: [
    "Science Fiction",
    "Artificial intelligence",
    "nyt:combined-print-and-e-book-fiction=2021-03-21",
    "Fiction, science fiction, general",
    "Coming of age"
  ],
  author_key: ["OL2627906A"],
  author_name: ["Kazuo Ishiguro"]
};

/** MusicBrainz release-group with inc=artist-credits+genres+tags+releases — Joni Mitchell, Blue. */
export const MB_BLUE_GROUP = {
  id: "1d5a3aa8-8a43-3fb1-b8f4-a8d1d3a2d7fc",
  title: "Blue",
  "first-release-date": "1971-06-22",
  "artist-credit": [
    { artist: { id: "5c5c1d6e-2b4a-4c3e-9f8b-1f8a3c2b7d10", name: "Joni Mitchell" } }
  ],
  genres: [
    { name: "folk", count: 6 },
    { name: "singer-songwriter", count: 4 },
    { name: "shoegaze", count: 0 }
  ],
  tags: [
    { name: "acoustic guitar", count: 3 },
    { name: "piano", count: 2 },
    { name: "mellow", count: 1 }
  ],
  releases: [
    { id: "rel-late", date: "1987", status: "Official" },
    { id: "rel-bootleg", date: "1970", status: "Bootleg" },
    { id: "rel-first", date: "1971-06-22", status: "Official" }
  ]
};

/** MusicBrainz release with inc=recordings — Blue's first pressing. */
export const MB_BLUE_RELEASE = {
  id: "rel-first",
  country: "US",
  "text-representation": { language: "eng" },
  media: [
    {
      tracks: [
        { length: 182000 },
        { length: 197000 },
        { length: 300000 },
        { length: 275000 },
        { length: 276000 }
      ]
    },
    {
      tracks: [
        { length: 290000 },
        { length: 244000 },
        { length: 270000 },
        { length: 266000 },
        { length: 233000 }
      ]
    }
  ]
};
