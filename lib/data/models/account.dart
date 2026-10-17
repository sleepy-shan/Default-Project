import 'media.dart';

/// Kinds of AniList notification the app surfaces ("updated anime").
enum NotificationKind { airing, relatedAddition, dataChange }

/// One AniList notification about a title (new episode, new related
/// title, or changed site data).
class UserNotification {
  const UserNotification({
    required this.id,
    required this.kind,
    required this.mediaId,
    required this.mediaType,
    required this.title,
    required this.message,
    required this.createdAt,
    this.coverUrl,
  });

  final int id;
  final NotificationKind kind;
  final int mediaId;
  final MediaType mediaType;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? coverUrl;
}

/// One genre with how many titles from the user's list carry it.
class GenreStat {
  const GenreStat({required this.genre, required this.count});

  final String genre;
  final int count;
}

/// A section of the signed-in user's AniList **anime** list.
///
/// Mirrors the AniList statistics strip: one entry per list status plus
/// "All" (every title) and "Favourites" (a separate AniList connection).
enum ProfileSection {
  all('All', null, false),
  watching('Watching', 'CURRENT', false),
  completed('Completed', 'COMPLETED', false),
  planning('Planning', 'PLANNING', false),
  paused('Paused', 'PAUSED', false),
  dropped('Dropped', 'DROPPED', false),
  rewatching('Rewatching', 'REPEATING', false),
  favourites('Favourites', null, true);

  const ProfileSection(this.label, this.status, this.favouritesOnly);

  final String label;

  /// AniList `MediaListStatus` wire value; null for "All" and "Favourites".
  final String? status;

  /// Favourites come from `User.favourites.anime`, not a list status.
  final bool favouritesOnly;

  /// The count to show beside this section, from the viewer's statistics.
  int countIn(ViewerProfile? profile) => switch (this) {
    ProfileSection.all => profile?.totalCount ?? 0,
    ProfileSection.watching => profile?.watching ?? 0,
    ProfileSection.completed => profile?.completed ?? 0,
    ProfileSection.planning => profile?.planning ?? 0,
    ProfileSection.paused => profile?.paused ?? 0,
    ProfileSection.dropped => profile?.dropped ?? 0,
    ProfileSection.rewatching => profile?.rewatching ?? 0,
    ProfileSection.favourites => profile?.favourites ?? 0,
  };

  /// Resolves a section name from a route, defaulting to [all].
  static ProfileSection fromName(String? name) {
    if (name == null || name.isEmpty) return ProfileSection.all;
    for (final section in ProfileSection.values) {
      if (section.name == name) return section;
    }
    return ProfileSection.all;
  }
}

/// One title on the user's AniList list, with their progress and score.
class AccountListEntry {
  const AccountListEntry({
    required this.media,
    required this.status,
    this.progress = 0,
    this.progressVolumes,
    this.score,
    this.updatedAt,
  });

  final Media media;

  /// AniList `MediaListStatus` wire value (empty for favourites).
  final String status;
  final int progress;
  final int? progressVolumes;

  /// AniList score in the user's own format (null when unrated).
  final double? score;
  final DateTime? updatedAt;
}

/// Kinds of AniList activity shown in the profile history.
enum ActivityKind { listUpdate, text, message }

/// One item from the user's AniList activity feed.
class UserActivity {
  const UserActivity({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.mediaId,
    this.mediaType,
    this.title,
    this.coverUrl,
    this.status,
    this.progress,
    this.text,
  });

  final int id;
  final ActivityKind kind;
  final DateTime createdAt;
  final int? mediaId;
  final MediaType? mediaType;
  final String? title;
  final String? coverUrl;

  /// AniList `MediaListStatus` wire value for list activities.
  final String? status;
  final int? progress;

  /// Text/message body for text and message activities.
  final String? text;
}

/// Signed-in user's header details and anime/manga statistics for the profile.
///
/// [completed], [planning], [paused], [dropped] and [rewatching] mirror the
/// AniList status buckets so the profile can render the same "watching /
/// completed / planning / paused / dropped / rewatching / favourites" strip
/// AniList shows.
class ViewerProfile {
  const ViewerProfile({
    required this.name,
    this.avatarUrl,
    this.bannerUrl,
    this.totalCount = 0,
    this.watching = 0,
    this.completed = 0,
    this.planning = 0,
    this.paused = 0,
    this.dropped = 0,
    this.rewatching = 0,
    this.favourites = 0,
    this.episodesWatched,
    this.minutesWatched,
    this.meanScore,
    this.mangaCount = 0,
    this.chaptersRead,
    this.volumesRead,
    this.mangaMeanScore,
    this.animeGenres = const [],
    this.mangaGenres = const [],
  });

  final String name;
  final String? avatarUrl;
  final String? bannerUrl;

  /// Every anime on the user's list (AniList `statistics.anime.count`).
  final int totalCount;

  /// Anime currently being watched (list status CURRENT).
  final int watching;

  /// Anime finished (list status COMPLETED).
  final int completed;

  /// Anime planned to watch (list status PLANNING).
  final int planning;

  /// Anime put on hold (list status PAUSED).
  final int paused;

  /// Anime dropped (list status DROPPED).
  final int dropped;

  /// Anime being rewatched (list status REPEATING).
  final int rewatching;

  /// Favourited anime (AniList `favourites.anime`).
  final int favourites;

  final int? episodesWatched;

  /// Total minutes of anime watched (used to derive [daysWatched]).
  final int? minutesWatched;

  /// AniList mean score on a 0-100 scale, when the user has scored titles.
  final double? meanScore;

  /// Every manga on the user's list (AniList `statistics.manga.count`).
  final int mangaCount;
  final int? chaptersRead;
  final int? volumesRead;

  /// Manga mean score on a 0-100 scale.
  final double? mangaMeanScore;

  /// Top anime genres by how many listed titles carry them.
  final List<GenreStat> animeGenres;

  /// Top manga genres by how many listed titles carry them.
  final List<GenreStat> mangaGenres;

  /// Whole days of anime watched, derived from [minutesWatched].
  double? get daysWatched {
    final minutes = minutesWatched;
    if (minutes == null) return null;
    return minutes / Duration.minutesPerDay;
  }

  /// Anime and manga genres merged by name, most titles first.
  List<GenreStat> get topGenres {
    final merged = <String, int>{};
    for (final stat in [...animeGenres, ...mangaGenres]) {
      merged.update(
        stat.genre,
        (value) => value + stat.count,
        ifAbsent: () => stat.count,
      );
    }
    final list = [
      for (final entry in merged.entries)
        GenreStat(genre: entry.key, count: entry.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }
}
