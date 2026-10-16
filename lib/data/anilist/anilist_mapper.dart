import '../models/account.dart';
import '../models/airing_schedule.dart';
import '../models/media.dart';
import '../models/people.dart';

/// Converts AniList JSON payloads into app models.
///
/// All parsing is defensive: AniList can omit fields, and titles may be
/// missing English or romaji variants, so every field has a fallback.
abstract final class AniListMapper {
  /// Parses a list of media nodes from a `Page.media` payload.
  static List<Media> mediaList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map(_media).whereType<Media>().toList(growable: false);
  }

  /// Parses a single `Media` object (detail page).
  static Media? single(Object? raw) => _media(raw);

  static Media? _media(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final id = (json['id'] as num?)?.toInt();
    if (id == null) return null;

    final type = MediaType.fromWire(json['type'] as String?);
    final title =
        (json['title'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const {};

    return Media(
      id: id,
      type: type,
      title: _title(title),
      coverUrl: _coverUrl(json['coverImage'] as Map?),
      bannerUrl: (json['bannerImage'] as String?)?.trim(),
      description: json['description'] as String?,
      genres:
          (json['genres'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      tags: _tags(json['tags'] as List?),
      format: MediaFormat.fromWire(json['format'] as String?),
      status: MediaStatus.fromWire(json['status'] as String?),
      season: MediaSeason.fromWire(json['season'] as String?),
      seasonYear: (json['seasonYear'] as num?)?.toInt(),
      episodes: (json['episodes'] as num?)?.toInt(),
      chapters: (json['chapters'] as num?)?.toInt(),
      volumes: (json['volumes'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      averageScore: (json['averageScore'] as num?)?.toInt(),
      meanScore: (json['meanScore'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      favourites: (json['favourites'] as num?)?.toInt(),
      studios: _studios(json['studios'] as Map?),
      source: (json['source'] as String?)?.replaceAll('_', ' '),
      countryOfOrigin: json['countryOfOrigin'] as String?,
      startDate: _fuzzyDate(json['startDate'] as Map?),
      endDate: _fuzzyDate(json['endDate'] as Map?),
      siteUrl: json['siteUrl'] as String?,
      nextAiringEpisode: _airing(json['nextAiringEpisode'] as Map?),
      relations: _relations(json['relations'] as Map?),
      recommendations: _recommendations(json['recommendations'] as Map?),
    );
  }

  /// English title wins, then romaji, then native, then a placeholder.
  static String _title(Map<dynamic, dynamic> title) {
    for (final key in const ['english', 'romaji', 'native']) {
      final value = title[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return 'Untitled';
  }

  static String _coverUrl(Map? coverImage) {
    if (coverImage == null) return '';
    for (final key in const ['extraLarge', 'large', 'medium']) {
      final value = coverImage[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return '';
  }

  static List<MediaTag> _tags(List? tags) {
    if (tags == null) return const [];
    return tags
        .whereType<Map>()
        .map(
          (tag) => MediaTag(
            name: (tag['name'] as String?)?.trim() ?? '',
            rank: (tag['rank'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((tag) => tag.name.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _studios(Map? studios) {
    final nodes = studios?['nodes'];
    if (nodes is! List) return const [];
    return nodes
        .whereType<Map>()
        .map((node) => (node['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  static List<MediaEdge> _relations(Map? relations) {
    final edges = relations?['edges'];
    if (edges is! List) return const [];
    return edges
        .whereType<Map>()
        .map((edge) {
          final node = _media(edge['node']);
          if (node == null) return null;
          return MediaEdge(
            relationType: _relationType(
              (edge['relationType'] as String?) ?? '',
            ),
            media: node,
          );
        })
        .whereType<MediaEdge>()
        .toList(growable: false);
  }

  static List<Media> _recommendations(Map? recommendations) {
    final nodes = recommendations?['nodes'];
    if (nodes is! List) return const [];
    return nodes
        .whereType<Map>()
        .map((node) => _media(node['mediaRecommendation']))
        .whereType<Media>()
        .toList(growable: false);
  }

  static NextAiringEpisode? _airing(Map? airing) {
    if (airing == null) return null;
    final episode = (airing['episode'] as num?)?.toInt();
    final at = (airing['airingAt'] as num?)?.toInt();
    if (episode == null || at == null) return null;
    return NextAiringEpisode(episode: episode, airingAt: at);
  }

  /// AniList uses fuzzy dates ({year, month, day}); build "YYYY-MM-DD" when a
  /// full date is available, otherwise null.
  static String? _fuzzyDate(Map? date) {
    if (date == null) return null;
    final year = (date['year'] as num?)?.toInt();
    final month = (date['month'] as num?)?.toInt();
    final day = (date['day'] as num?)?.toInt();
    if (year == null || month == null || day == null) return null;
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// "SEQUEL" -> "Sequel", "SIDE_STORY" -> "Side Story".
  static String _relationType(String wire) {
    if (wire.trim().isEmpty) return 'Related';
    final words = wire.toLowerCase().split('_');
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static List<AiringScheduleItem> airingSchedule(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final media = item['media'];
          final mediaMap = media is Map
              ? media.map((key, value) => MapEntry(key.toString(), value))
              : const {};
          return AiringScheduleItem(
            id: (item['id'] as num?)?.toInt() ?? 0,
            mediaId: (mediaMap['id'] as num?)?.toInt() ?? 0,
            mediaType: MediaType.fromWire(mediaMap['type'] as String?),
            title: AniListMapper._title(
              (mediaMap['title'] as Map?)?.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ) ??
                  const {},
            ),
            coverUrl: AniListMapper._coverUrl(mediaMap['coverImage'] as Map?),
            episode: (item['episode'] as num?)?.toInt() ?? 0,
            airingAt: (item['airingAt'] as num?)?.toInt() ?? 0,
            totalEpisodes: (mediaMap['episodes'] as num?)?.toInt(),
            averageScore: (mediaMap['averageScore'] as num?)?.toInt(),
          );
        })
        .toList(growable: false);
  }

  /// Parses a `Page.characters` payload for the search tab.
  static List<SearchCharacter> characters(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = item.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final id = (map['id'] as num?)?.toInt();
          if (id == null) return null;
          final name = (map['name'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value),
              ) ??
              const {};
          final full = (name['full'] as String?)?.trim() ?? '';
          if (full.isEmpty) return null;
          final image = (map['image'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value),
              ) ??
              const {};
          return SearchCharacter(
            id: id,
            nameFull: full,
            nameNative: (name['native'] as String?)?.trim(),
            imageUrl: (image['large'] as String?)?.trim() ?? '',
            favourites: (map['favourites'] as num?)?.toInt() ?? 0,
          );
        })
        .whereType<SearchCharacter>()
        .toList(growable: false);
  }

  /// Parses a `Page.staff` payload for the search tab.
  static List<SearchStaff> staff(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = item.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final id = (map['id'] as num?)?.toInt();
          if (id == null) return null;
          final name = (map['name'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value),
              ) ??
              const {};
          final full = (name['full'] as String?)?.trim() ?? '';
          if (full.isEmpty) return null;
          final image = (map['image'] as Map?)?.map(
                (key, value) => MapEntry(key.toString(), value),
              ) ??
              const {};
          final occupations = (map['primaryOccupations'] as List?)
                  ?.map((e) => e.toString().replaceAll('_', ' '))
                  .where((e) => e.trim().isNotEmpty)
                  .toList(growable: false) ??
              const [];
          return SearchStaff(
            id: id,
            nameFull: full,
            nameNative: (name['native'] as String?)?.trim(),
            imageUrl: (image['large'] as String?)?.trim() ?? '',
            favourites: (map['favourites'] as num?)?.toInt() ?? 0,
            role: occupations.join(' · '),
          );
        })
        .whereType<SearchStaff>()
        .toList(growable: false);
  }

  /// Parses a `Page.studios` payload for the search tab.
  static List<SearchStudio> studios(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = item.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final id = (map['id'] as num?)?.toInt();
          if (id == null) return null;
          final name = (map['name'] as String?)?.trim() ?? '';
          if (name.isEmpty) return null;
          return SearchStudio(
            id: id,
            name: name,
            favourites: (map['favourites'] as num?)?.toInt() ?? 0,
            isAnimationStudio: map['isAnimationStudio'] != false,
          );
        })
        .whereType<SearchStudio>()
        .toList(growable: false);
  }

  /// Reads `Page.pageInfo` for the people/studio search endpoints.
  static ({int page, bool hasNextPage}) pageInfo(
    Object? raw,
    int fallbackPage,
  ) {
    if (raw is! Map) return (page: fallbackPage, hasNextPage: false);
    final info = (raw['pageInfo'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const {};
    return (
      page: (info['currentPage'] as num?)?.toInt() ?? fallbackPage,
      hasNextPage: info['hasNextPage'] == true,
    );
  }

  /// Parses `Staff(id:)` into a profile plus the merged list of titles they
  /// voiced (`characterMedia`) or worked on (`staffMedia`).
  static PersonWorks? staffWorks(Object? raw, int fallbackPage) {
    final map = _asMap(raw);
    if (map == null) return null;
    final profile = _profile(map, withRole: true);
    if (profile == null) return null;
    return PersonWorks(
      person: profile,
      works: _mergeConnections(
        [map['characterMedia'], map['staffMedia']],
        fallbackPage,
      ),
    );
  }

  /// Parses `Character(id:)` into a profile plus the series they appear in.
  static PersonWorks? characterWorks(Object? raw, int fallbackPage) {
    final map = _asMap(raw);
    if (map == null) return null;
    final profile = _profile(map);
    if (profile == null) return null;
    return PersonWorks(
      person: profile,
      works: _mergeConnections([map['media']], fallbackPage),
    );
  }

  /// Parses `Studio(id:)` into a profile plus the titles it produced.
  static PersonWorks? studioWorks(Object? raw, int fallbackPage) {
    final map = _asMap(raw);
    if (map == null) return null;
    final id = (map['id'] as num?)?.toInt();
    final name = (map['name'] as String?)?.trim() ?? '';
    if (id == null || name.isEmpty) return null;
    return PersonWorks(
      person: PersonProfile(
        id: id,
        nameFull: name,
        favourites: (map['favourites'] as num?)?.toInt() ?? 0,
        role: map['isAnimationStudio'] == false
            ? 'Studio'
            : 'Animation studio',
      ),
      works: _mergeConnections([map['media']], fallbackPage),
    );
  }

  /// Parses `Page.notifications` (airing / related addition / data change).
  /// Unknown or media-less notifications are skipped.
  static List<UserNotification> notifications(Object? raw) {
    if (raw is! List) return const [];
    final out = <UserNotification>[];
    for (final item in raw) {
      final map = _asMap(item);
      if (map == null) continue;
      final id = (map['id'] as num?)?.toInt();
      final type = map['type'] as String?;
      if (id == null || type == null) continue;
      final parsed = mediaList([map['media']]);
      if (parsed.isEmpty) continue;
      final media = parsed.first;

      final NotificationKind kind;
      final String message;
      switch (type) {
        case 'AIRING':
          final episode = (map['episode'] as num?)?.toInt();
          kind = NotificationKind.airing;
          message = episode == null
              ? 'A new episode aired'
              : 'Episode $episode aired';
        case 'RELATED_MEDIA_ADDITION':
          kind = NotificationKind.relatedAddition;
          message = 'A related title was added';
        case 'MEDIA_DATA_CHANGE':
          final reason = (map['reason'] as String?)?.trim() ?? '';
          kind = NotificationKind.dataChange;
          message = reason.isEmpty ? 'Details were updated' : reason;
        default:
          continue;
      }
      final seconds = (map['createdAt'] as num?)?.toInt() ?? 0;
      out.add(
        UserNotification(
          id: id,
          kind: kind,
          mediaId: media.id,
          mediaType: media.type,
          title: media.title,
          coverUrl: media.coverUrl,
          message: message,
          createdAt: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
        ),
      );
    }
    return out;
  }

  /// Parses `Viewer` (statistics + favorites) for the profile page.
  static ViewerProfile? viewerProfile(Object? raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    final name = (map['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    final anime = _asMap(_asMap(map['statistics'])?['anime']);
    final counts = <String, int>{};
    final statuses = anime?['statuses'];
    if (statuses is List) {
      for (final entry in statuses) {
        final status = _asMap(entry);
        final key = status?['status'];
        if (key is String) {
          counts[key] = (status?['count'] as num?)?.toInt() ?? 0;
        }
      }
    }
    final banner = (map['bannerImage'] as String?)?.trim();
    return ViewerProfile(
      name: name,
      avatarUrl: _asMap(map['avatar'])?['large'] as String?,
      bannerUrl: banner == null || banner.isEmpty ? null : banner,
      watching: counts['CURRENT'] ?? 0,
      episodesWatched: (anime?['episodesWatched'] as num?)?.toInt(),
      meanScore: (anime?['meanScore'] as num?)?.toDouble(),
      statusCounts: counts,
      favorites: _favorites(_asMap(map['favourites'])),
    );
  }

  static List<ProfileFavorite> _favorites(Map<String, dynamic>? raw) {
    if (raw == null) return const [];
    final out = <ProfileFavorite>[];

    List<Map<String, dynamic>> nodes(String key) {
      final list = _asMap(raw[key])?['nodes'];
      if (list is! List) return const [];
      return list.map(_asMap).whereType<Map<String, dynamic>>().toList();
    }

    for (final kind in const [FavoriteKind.anime, FavoriteKind.manga]) {
      for (final node in nodes(kind.name)) {
        final id = (node['id'] as num?)?.toInt();
        if (id == null) continue;
        final year =
            (node['seasonYear'] as num?)?.toInt() ??
            (_asMap(node['startDate'])?['year'] as num?)?.toInt();
        final format = MediaFormat.fromWire(node['format'] as String?);
        final subtitle = [
          if (format != MediaFormat.unknown) format.label,
          if (year != null) '$year',
        ].join(' · ');
        out.add(
          ProfileFavorite(
            id: id,
            kind: kind,
            name: _title(_asMap(node['title']) ?? const {}),
            imageUrl: _coverUrl(_asMap(node['coverImage'])),
            subtitle: subtitle.isEmpty ? null : subtitle,
          ),
        );
      }
    }

    for (final node in nodes('characters')) {
      final id = (node['id'] as num?)?.toInt();
      final full = (_asMap(node['name'])?['full'] as String?)?.trim();
      if (id == null || full == null || full.isEmpty) continue;
      final series = _asMap(node['media'])?['nodes'];
      String? from;
      if (series is List && series.isNotEmpty) {
        from = _title(_asMap(_asMap(series.first)?['title']) ?? const {});
      }
      out.add(
        ProfileFavorite(
          id: id,
          kind: FavoriteKind.character,
          name: full,
          imageUrl: _asMap(node['image'])?['large'] as String?,
          subtitle: from,
        ),
      );
    }
    return out;
  }

  static PersonProfile? _profile(
    Map<String, dynamic> map, {
    bool withRole = false,
  }) {
    final id = (map['id'] as num?)?.toInt();
    if (id == null) return null;
    final name = _asMap(map['name']) ?? const <String, dynamic>{};
    final full = (name['full'] as String?)?.trim() ?? '';
    if (full.isEmpty) return null;
    final image = _asMap(map['image']) ?? const <String, dynamic>{};
    final role = withRole
        ? ((map['primaryOccupations'] as List?)
                  ?.map((e) => e.toString().replaceAll('_', ' '))
                  .where((e) => e.trim().isNotEmpty)
                  .join(' · ') ??
              '')
        : '';
    return PersonProfile(
      id: id,
      nameFull: full,
      nameNative: (name['native'] as String?)?.trim(),
      imageUrl: (image['large'] as String?)?.trim() ?? '',
      favourites: (map['favourites'] as num?)?.toInt() ?? 0,
      role: role,
    );
  }

  /// Merges one or more `MediaConnection`s: de-duplicates by media id
  /// (a voice actor can voice several characters in one show) and orders by
  /// popularity. A next page exists if any connection has one.
  static MediaPage _mergeConnections(
    List<Object?> connections,
    int fallbackPage,
  ) {
    final seen = <int>{};
    final items = <Media>[];
    var page = fallbackPage;
    var hasNext = false;
    for (final raw in connections) {
      final connection = _asMap(raw);
      if (connection == null) continue;
      final info = _asMap(connection['pageInfo']);
      page = (info?['currentPage'] as num?)?.toInt() ?? page;
      if (info?['hasNextPage'] == true) hasNext = true;
      for (final media in mediaList(connection['nodes'])) {
        if (seen.add(media.id)) items.add(media);
      }
    }
    items.sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
    return MediaPage(items: items, page: page, hasNextPage: hasNext);
  }

  static Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
