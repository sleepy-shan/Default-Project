import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/anilist/anilist_client.dart';
import '../data/models/media.dart';
import '../data/repositories/media_repository.dart';

/// Shared AniList HTTP client and repository.
final aniListClientProvider = Provider<AniListClient>((ref) {
  final client = AniListClient();
  ref.onDispose(client.close);
  return client;
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(ref.watch(aniListClientProvider));
});

/// Home page rails.
enum MediaRail {
  trendingAnime,
  trendingManga,
  popularThisSeason,
}

final mediaRailProvider =
    FutureProvider.family<MediaPage, MediaRail>((ref, rail) async {
  final repo = ref.watch(mediaRepositoryProvider);
  switch (rail) {
    case MediaRail.trendingAnime:
      return repo.trending(type: MediaType.anime, perPage: 12);
    case MediaRail.trendingManga:
      return repo.trending(type: MediaType.manga, perPage: 12);
    case MediaRail.popularThisSeason:
      return repo.browse(
        BrowseQuery(
          type: MediaType.anime,
          sort: MediaSort.popularity,
          seasonYear: DateTime.now().year,
          perPage: 12,
        ),
      );
  }
});

/// Media detail for a title id.
final mediaDetailProvider =
    FutureProvider.family.autoDispose<Media, int>((ref, id) async {
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.mediaDetail(id);
});
