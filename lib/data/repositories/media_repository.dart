import '../anilist/anilist_client.dart';
import '../anilist/anilist_mapper.dart';
import '../anilist/anilist_queries.dart';
import '../models/airing_schedule.dart';
import '../models/media.dart';

/// Search/browse criteria passed to [MediaRepository.browse].
class BrowseQuery {
  const BrowseQuery({
    this.type = MediaType.anime,
    this.sort = MediaSort.trending,
    this.search = '',
    this.genre,
    this.status,
    this.format,
    this.season,
    this.seasonYear,
    this.page = 1,
    this.perPage = 24,
  });

  final MediaType type;
  final MediaSort sort;
  final String search;
  final String? genre;
  final MediaStatus? status;
  final MediaFormat? format;
  final MediaSeason? season;
  final int? seasonYear;
  final int page;
  final int perPage;

  /// True when the query has any active filter (used to show "clear" UI).
  bool get hasFilters =>
      search.trim().isNotEmpty ||
      (genre != null && genre!.isNotEmpty) ||
      status != null ||
      format != null ||
      season != null ||
      seasonYear != null;

  BrowseQuery copyWith({
    MediaType? type,
    MediaSort? sort,
    String? search,
    String? genre,
    MediaStatus? status,
    MediaFormat? format,
    MediaSeason? season,
    int? seasonYear,
    int? page,
    int? perPage,
    bool clearFilters = false,
  }) {
    return BrowseQuery(
      type: type ?? this.type,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      // With clearFilters, null explicitly clears the filter.
      genre: clearFilters ? genre : (genre ?? this.genre),
      status: clearFilters ? status : (status ?? this.status),
      format: clearFilters ? format : (format ?? this.format),
      season: clearFilters ? season : (season ?? this.season),
      seasonYear: clearFilters ? seasonYear : (seasonYear ?? this.seasonYear),
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }
}

/// Loads public anime/manga metadata from AniList.
///
/// AniList is treated as the source of truth for metadata; this app never
/// re-hosts its data, it only caches transiently in memory.
class MediaRepository {
  MediaRepository(this._client);

  final AniListClient _client;

  /// Trending rail for the home page.
  Future<MediaPage> trending({
    MediaType type = MediaType.anime,
    int page = 1,
    int perPage = 10,
  }) async {
    final data = await _client.query(trendingQuery(detail: false), {
      'page': page,
      'perPage': perPage,
      'type': type.anilistValue,
    });
    return _page(data, page);
  }

  /// Browse results with the full filter set.
  ///
  /// Uses the detailed selection so detail data is already available.
  Future<MediaPage> browse(BrowseQuery query) async {
    // AniList treats an explicitly-null `status` as "match nothing", so
    // unset filters are omitted from the variables map entirely.
    final variables = <String, dynamic>{
      'page': query.page,
      'perPage': query.perPage,
      'type': query.type.anilistValue,
      'sort': [query.sort.wire],
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      if (query.genre != null && query.genre!.isNotEmpty) 'genre': query.genre,
      if (query.status != null) 'status': query.status!.wire,
      if (query.format != null && query.format != MediaFormat.unknown)
        'format': query.format!.wire,
      if (query.season != null && query.season != MediaSeason.unknown)
        'season': query.season!.wire,
      if (query.seasonYear != null) 'seasonYear': query.seasonYear,
    };

    // Lists use the light selection (relations/recommendations make a
    // 24-item query far too slow on AniList); the detail page fetches
    // those fields for a single title by id.
    final data = await _client.query(browseQuery(detail: false), variables);
    return _page(data, query.page);
  }

  /// Full detail for one title.
  Future<Media> mediaDetail(int id) async {
    final data = await _client.query(kMediaDetailQuery, {'id': id});
    final media = AniListMapper.single(data['Media']);
    if (media == null) {
      throw Exception('Title $id is unavailable');
    }
    return media;
  }

  /// Airing schedule between [from] and [to] (epoch seconds).
  Future<List<AiringScheduleItem>> airingSchedule({
    required int from,
    required int to,
    int page = 1,
    int perPage = 50,
  }) async {
    final data = await _client.query(kAiringScheduleQuery, {
      'page': page,
      'perPage': perPage,
      'airingAt_greater': from,
      'airingAt_lesser': to,
    });
    final pageJson =
        (data['Page'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const {};
    return AniListMapper.airingSchedule(pageJson['airingSchedules']);
  }

  MediaPage _page(Map<String, dynamic> data, int fallbackPage) {
    final raw = data['Page'];
    final pageJson = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : const {};
    final info =
        (pageJson['pageInfo'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const {};
    return MediaPage(
      items: AniListMapper.mediaList(pageJson['media']),
      page: (info['currentPage'] as num?)?.toInt() ?? fallbackPage,
      hasNextPage: info['hasNextPage'] == true,
    );
  }
}
