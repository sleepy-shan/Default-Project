import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anilist/anilist_client.dart';
import '../data/models/airing_schedule.dart';
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
enum MediaRail {
  trendingAnime,
  trendingManga,
  popularThisSeason,
  airingNow,
  allTimePopular,
  upcoming,
  topRated,
  topCompleted,
  newChapters,
}

final mediaRailProvider =
    FutureProvider.family.autoDispose<MediaPage, (MediaRail, MediaType)>((
      ref,
      key,
    ) async {
  final (rail, type) = key;
  final repo = ref.watch(mediaRepositoryProvider);
  BrowseQuery query({MediaSort sort = MediaSort.trending, MediaStatus? status}) {
    return BrowseQuery(type: type, sort: sort, status: status, perPage: 12);
  }

  switch (rail) {
    case MediaRail.trendingAnime:
    case MediaRail.trendingManga:
      return repo.trending(type: type, perPage: 12);
    case MediaRail.popularThisSeason:
      if (type == MediaType.manga) {
        // Seasons are anime-only on AniList; manga falls back to popularity.
        return repo.browse(query(sort: MediaSort.popularity));
      }
      final now = DateTime.now();
      return repo.browse(
        BrowseQuery(
          type: type,
          sort: MediaSort.popularity,
          // AniList needs a season together with seasonYear for anime.
          season: currentSeason(now.month),
          seasonYear: now.year,
          perPage: 12,
        ),
      );
    case MediaRail.airingNow:
      return repo.browse(query(status: MediaStatus.releasing));
    case MediaRail.allTimePopular:
      return repo.browse(query(sort: MediaSort.popularity));
    case MediaRail.upcoming:
      return repo.browse(
        query(sort: MediaSort.popularity, status: MediaStatus.notYetReleased),
      );
    case MediaRail.topRated:
      return repo.browse(query(sort: MediaSort.score));
    case MediaRail.topCompleted:
      return repo.browse(
        query(sort: MediaSort.score, status: MediaStatus.finished),
      );
    case MediaRail.newChapters:
      return repo.browse(query(sort: MediaSort.updated));
  }
});

/// Episodes airing today (midnight to midnight, local time).
///
/// `autoDispose` for the same reason as [mediaRailProvider]; the repository
/// TTL cache keeps revisits cheap.
final airingTodayProvider =
    FutureProvider.autoDispose<List<AiringScheduleItem>>((ref) async {
  final repo = ref.watch(mediaRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return repo.airingSchedule(
    from: start.millisecondsSinceEpoch ~/ 1000,
    to: end.millisecondsSinceEpoch ~/ 1000,
    perPage: 24,
  );
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
