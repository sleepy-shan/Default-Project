import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anilist/anilist_client.dart';
import '../data/models/media.dart';
import '../data/repositories/media_repository.dart';

/// Shared AniList HTTP client and repository.
///
/// The client is intentionally kept alive for the app lifetime (single
/// socket pool); [MediaRepository] adds its own TTL cache on top so
/// repeated rail/detail visits do not burn the 90 req/min AniList budget.
final aniListClientProvider = Provider<AniListClient>((ref) {
  final client = AniListClient();
  ref.onDispose(client.close);
  return client;
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  // `read` would also work; `watch` keeps rails in sync if the client
  // is ever overridden in tests.
  return MediaRepository(ref.watch(aniListClientProvider));
});

/// Home page rails.
///
/// `autoDispose` so rails are released when the home screen is gone;
/// data is re-fetched on return (backed by the repository TTL cache,
/// so revisits are usually instant and network-free).
enum MediaRail { trendingAnime, trendingManga, popularThisSeason }

final mediaRailProvider =
    FutureProvider.family.autoDispose<MediaPage, MediaRail>((ref, rail) async {
  final repo = ref.watch(mediaRepositoryProvider);
  switch (rail) {
    case MediaRail.trendingAnime:
      return repo.trending(type: MediaType.anime, perPage: 12);
    case MediaRail.trendingManga:
      return repo.trending(type: MediaType.manga, perPage: 12);
    case MediaRail.popularThisSeason:
      final now = DateTime.now();
      return repo.browse(
        BrowseQuery(
          type: MediaType.anime,
          sort: MediaSort.popularity,
          // AniList needs a season together with seasonYear for anime.
          season: currentSeason(now.month),
          seasonYear: now.year,
          perPage: 12,
        ),
      );
  }
});

/// Anime season for a calendar month number.
MediaSeason currentSeason(int month) {
  if (month <= 2 || month == 12) return MediaSeason.winter;
  if (month <= 5) return MediaSeason.spring;
  if (month <= 8) return MediaSeason.summer;
  return MediaSeason.fall;
}

/// Media detail for a title id.
final mediaDetailProvider = FutureProvider.family.autoDispose<Media, int>((
  ref,
  id,
) async {
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.mediaDetail(id);
});
