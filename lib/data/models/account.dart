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
class ViewerProfile {
  const ViewerProfile({
    required this.name,
    this.avatarUrl,
    this.bannerUrl,
    this.watching = 0,
    this.episodesWatched,
    this.meanScore,
  });

  final String name;
  final String? avatarUrl;
  final String? bannerUrl;

  /// Anime currently being watched (list status CURRENT).
  final int watching;
  final int? episodesWatched;

  /// AniList mean score on a 0-100 scale, when the user has scored titles.
  final double? meanScore;
}
