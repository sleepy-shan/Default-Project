import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../data/models/media.dart';
import '../data/repositories/media_repository.dart';
import 'load_state.dart';
import 'media_providers.dart';

class BrowseState {
  const BrowseState({
    this.query = const BrowseQuery(),
    this.status = LoadStatus.initial,
    this.items = const [],
    this.hasNextPage = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final BrowseQuery query;
  final LoadStatus status;

  /// Items currently loaded (accumulated across pages).
  final List<Media> items;
  final bool hasNextPage;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isFiltered => query.hasFilters;

  BrowseState copyWith({
    BrowseQuery? query,
    LoadStatus? status,
    List<Media>? items,
    bool? hasNextPage,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return BrowseState(
      query: query ?? this.query,
      status: status ?? this.status,
      items: items ?? this.items,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
    );
  }
}

/// Drives the Anime and Manga browse screens: filters + infinite scroll.
///
/// Smart state: a monotonic [_requestId] discards stale responses when
/// filters change rapidly or `loadMore` overlaps a fresh `load`.
class BrowseController extends Notifier<BrowseState> {
  BrowseController(this.mediaType);

  final MediaType mediaType;
  int _requestId = 0;
  MediaRepository get _repo => ref.read(mediaRepositoryProvider);

  @override
  BrowseState build() {
    // Re-fetch whenever the media type changes (route change).
    Future.microtask(load);
    return BrowseState(query: BrowseQuery(type: mediaType));
  }

  Future<void> load() async {
    final id = ++_requestId;
    state = state.copyWith(status: LoadStatus.loading, errorMessage: null);
    try {
      final page = await _repo.browse(state.query.copyWith(page: 1));
      if (id != _requestId) return; // superseded by a newer request.
      state = state.copyWith(
        status: LoadStatus.success,
        items: page.items,
        hasNextPage: page.hasNextPage,
        errorMessage: null,
      );
    } on AppException catch (error) {
      if (id != _requestId) return;
      state = state.copyWith(
        status: LoadStatus.error,
        errorMessage: error.userMessage,
      );
    } catch (error) {
      if (id != _requestId) return;
      state = state.copyWith(
        status: LoadStatus.error,
        errorMessage: 'Could not load titles: $error',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNextPage) return;
    final id = _requestId;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.query.page + 1;
      final page = await _repo.browse(state.query.copyWith(page: nextPage));
      if (id != _requestId) return; // a fresh load superseded pagination.
      state = state.copyWith(
        query: state.query.copyWith(page: nextPage),
        items: [...state.items, ...page.items],
        hasNextPage: page.hasNextPage,
        isLoadingMore: false,
      );
    } catch (_) {
      // Keep existing items visible; user can scroll again to retry.
      if (id == _requestId) state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> setSearch(String search) async {
    state = state.copyWith(query: state.query.copyWith(search: search));
    await load();
  }

  /// Applies the whole filter set at once and performs a single reload.
  Future<void> applyFilters({
    String? genre,
    MediaStatus? status,
    MediaFormat? format,
    MediaSeason? season,
    int? seasonYear,
    MediaSort? sort,
  }) async {
    state = state.copyWith(
      query: state.query.copyWith(
        genre: genre,
        status: status,
        format: format,
        season: season,
        seasonYear: seasonYear,
        sort: sort ?? state.query.sort,
        clearFilters: true,
      ),
    );
    await load();
  }

  Future<void> setStatus(MediaStatus? status) async {
    state = state.copyWith(query: state.query.copyWith(status: status));
    await load();
  }

  Future<void> setFormat(MediaFormat? format) async {
    state = state.copyWith(query: state.query.copyWith(format: format));
    await load();
  }

  Future<void> setSeason(MediaSeason? season) async {
    state = state.copyWith(query: state.query.copyWith(season: season));
    await load();
  }

  Future<void> setYear(int? year) async {
    state = state.copyWith(query: state.query.copyWith(seasonYear: year));
    await load();
  }

  Future<void> setSort(MediaSort sort) async {
    state = state.copyWith(query: state.query.copyWith(sort: sort));
    await load();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      query: BrowseQuery(type: mediaType, sort: state.query.sort),
    );
    await load();
  }

  Future<void> retry() => load();
}

final browseControllerProvider =
    NotifierProvider.family<BrowseController, BrowseState, MediaType>(
      BrowseController.new,
    );
