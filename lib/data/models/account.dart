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

/// Signed-in user's header details and anime statistics for the profile.
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
    this.meanScore,
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

  /// AniList mean score on a 0-100 scale, when the user has scored titles.
  final double? meanScore;
}
