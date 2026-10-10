import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../data/models/media.dart';
import '../data/repositories/media_repository.dart';
import 'load_state.dart';
import 'media_providers.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.typeFilter = MediaType.anime,
    this.status = LoadStatus.initial,
    this.results = const [],
    this.errorMessage,
  });

  final String query;

  /// anime / manga / all is expressed with three values; null = all.
  final MediaType? typeFilter;
  final LoadStatus status;
  final List<Media> results;
  final String? errorMessage;

  /// True once a search has run (used to decide empty vs. prompt states).
  bool get hasSearched =>
      status != LoadStatus.initial && query.trim().isNotEmpty;

  SearchState copyWith({
    String? query,
    MediaType? typeFilter,
    LoadStatus? status,
    List<Media>? results,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      typeFilter: typeFilter ?? this.typeFilter,
      status: status ?? this.status,
      results: results ?? this.results,
      errorMessage: errorMessage,
    );
  }
}

/// Debounced full-text search across anime and manga.
class SearchController extends Notifier<SearchState> {
  static const Duration _debounce = Duration(milliseconds: 400);
  Timer? _timer;

  MediaRepository get _repo => ref.read(mediaRepositoryProvider);

  @override
  SearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SearchState();
  }

  /// Called on every keystroke; the actual request fires after a pause.
  void onQueryChanged(String value) {
    state = state.copyWith(query: value);
    _timer?.cancel();
    if (value.trim().isEmpty) {
      state = state.copyWith(
        status: LoadStatus.initial,
        results: const [],
        errorMessage: null,
      );
      return;
    }
    _timer = Timer(_debounce, () => runSearch());
  }

  Future<void> setTypeFilter(MediaType? type) async {
    state = state.copyWith(typeFilter: type);
    if (state.query.trim().isNotEmpty) {
      await runSearch();
    }
  }

  Future<void> submit(String value) async {
    _timer?.cancel();
    state = state.copyWith(query: value);
    await runSearch();
  }

  Future<void> runSearch() async {
    final query = state.query.trim();
    if (query.isEmpty) return;
    state = state.copyWith(status: LoadStatus.loading, errorMessage: null);
    try {
      // AniList's `search` accepts a single type, so run one request per
      // type when the "All" filter is active.
      final types = state.typeFilter == null
          ? [MediaType.anime, MediaType.manga]
          : [state.typeFilter!];
      final pages = await Future.wait(
        types.map(
          (type) => _repo.browse(
            BrowseQuery(
              type: type,
              sort: MediaSort.popularity,
              search: query,
              perPage: 12,
            ),
          ),
        ),
      );
      state = state.copyWith(
        status: LoadStatus.success,
        results: pages.expand((page) => page.items).toList(),
        errorMessage: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        status: LoadStatus.error,
        errorMessage: error.userMessage,
      );
    } catch (error) {
      state = state.copyWith(
        status: LoadStatus.error,
        errorMessage: 'Search failed: $error',
      );
    }
  }

  void clear() {
    _timer?.cancel();
    state = const SearchState();
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
