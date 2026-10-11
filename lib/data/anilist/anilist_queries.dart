/// GraphQL documents used against the AniList API.
///
/// Field selections are kept identical between list and detail queries so a
/// single mapper can be used for both.
library;

/// Selection shared by every card and detail header.
const String kMediaListSelection = '''
  id
  idMal
  type
  format
  status
  season
  seasonYear
  episodes
  chapters
  volumes
  duration
  averageScore
  meanScore
  popularity
  favourites
  source
  countryOfOrigin
  startDate { year month day }
  endDate { year month day }
  siteUrl
  title { romaji english native }
  coverImage { extraLarge large color }
  bannerImage
  description(asHtml: false)
  genres
  nextAiringEpisode { episode airingAt timeUntilAiring }
  studios(isMain: true) { nodes { name } }
''';

/// Extra fields only needed on the detail page.
const String kMediaDetailSelection = '''$kMediaListSelection
  tags { name rank isMediaSpoiler }
  relations { edges { relationType(version: 2) node { id type
      title { romaji english native }
      coverImage { large }
      format status averageScore } } }
  recommendations(sort: RATING_DESC, perPage: 12) { nodes { mediaRecommendation { id type
      title { romaji english native }
      coverImage { large }
      format status averageScore } } }
''';

/// Trending + popular rails on the home page.
String trendingQuery({required bool detail}) => detail
    ? '''
query (\$page: Int, \$perPage: Int, \$type: MediaType) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage hasNextPage total }
    media(type: \$type, sort: TRENDING_DESC) { $kMediaDetailSelection }
  }
}'''
    : '''
query (\$page: Int, \$perPage: Int, \$type: MediaType) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage hasNextPage total }
    media(type: \$type, sort: TRENDING_DESC) { $kMediaListSelection }
  }
}''';

/// Browse with the filter set offered by the UI.
String browseQuery({required bool detail}) => detail
    ? '''
query (
  \$page: Int, \$perPage: Int, \$type: MediaType, \$sort: [MediaSort],
  \$search: String, \$genre: String, \$status: MediaStatus,
  \$format: MediaFormat, \$season: MediaSeason, \$seasonYear: Int
) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage hasNextPage total }
    media(
      type: \$type, sort: \$sort, search: \$search, genre: \$genre,
      status: \$status, format: \$format, season: \$season, seasonYear: \$seasonYear
    ) { $kMediaDetailSelection }
  }
}'''
    : '''
query (
  \$page: Int, \$perPage: Int, \$type: MediaType, \$sort: [MediaSort],
  \$search: String, \$genre: String, \$status: MediaStatus,
  \$format: MediaFormat, \$season: MediaSeason, \$seasonYear: Int
) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage hasNextPage total }
    media(
      type: \$type, sort: \$sort, search: \$search, genre: \$genre,
      status: \$status, format: \$format, season: \$season, seasonYear: \$seasonYear
    ) { $kMediaListSelection }
  }
}''';

/// Single media lookup used by the detail screen.
const String kMediaDetailQuery =
    '''
query (\$id: Int) {
  Media(id: \$id) { $kMediaDetailSelection }
}''';

/// Authenticated viewer lookup used to validate an AniList OAuth token.
const String kViewerQuery = '''
query {
  Viewer {
    id
    name
    avatar { large }
  }
}''';

/// Airing schedule for a time window (epoch seconds).
const String kAiringScheduleQuery = '''
query (\$page: Int, \$perPage: Int, \$airingAt_greater: Int, \$airingAt_lesser: Int) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage hasNextPage total }
    airingSchedules(
      airingAt_greater: \$airingAt_greater,
      airingAt_lesser: \$airingAt_lesser,
      sort: TIME
    ) {
      id
      episode
      airingAt
      media {
        id
        type
        title { romaji english native }
        coverImage { large }
      }
    }
  }
}''';
