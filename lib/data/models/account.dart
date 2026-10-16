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

/// What a favorite entry points at.
enum FavoriteKind {
  anime('Anime'),
  manga('Manga'),
  character('Characters');

  const FavoriteKind(this.label);

  final String label;
}

/// One favorite shown on the profile shelf (title or character).
class ProfileFavorite {
  const ProfileFavorite({
    required this.id,
    required this.kind,
    required this.name,
    this.imageUrl,
    this.subtitle,
  });

  final int id;
  final FavoriteKind kind;
  final String name;
  final String? imageUrl;

  /// Short secondary line, e.g. "TV · 2019" or the character's series.
  final String? subtitle;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'image': imageUrl,
    'subtitle': subtitle,
  };

  static ProfileFavorite? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as num?)?.toInt();
    final name = raw['name'] as String?;
    if (id == null || name == null || name.isEmpty) return null;
    final kind = FavoriteKind.values.firstWhere(
      (k) => k.name == raw['kind'],
      orElse: () => FavoriteKind.anime,
    );
    return ProfileFavorite(
      id: id,
      kind: kind,
      name: name,
      imageUrl: raw['image'] as String?,
      subtitle: raw['subtitle'] as String?,
    );
  }
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
    this.statusCounts = const {},
    this.favorites = const [],
  });

  final String name;
  final String? avatarUrl;
  final String? bannerUrl;

  /// Anime currently being watched (list status CURRENT).
  final int watching;
  final int? episodesWatched;

  /// AniList mean score on a 0-100 scale, when the user has scored titles.
  final double? meanScore;

  /// Anime list size per status (AniList wire values: CURRENT, COMPLETED,
  /// PLANNING, PAUSED, DROPPED, REPEATING).
  final Map<String, int> statusCounts;

  /// The user's AniList favorites: anime, manga and characters.
  final List<ProfileFavorite> favorites;
}
