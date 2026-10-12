import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../data/models/media.dart';
import '../data/models/people.dart';
import '../data/repositories/media_repository.dart';
import 'load_state.dart';
import 'media_providers.dart';

/// Search tabs matching the reference design.
enum SearchTab { anime, studios, staff, characters }

/// One paged result set for a search tab.
class TabPage<T> {
  const TabPage({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.page = 1,
    this.hasNextPage = false,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<T> items;
  final int page;
  final bool hasNextPage;
  final String? errorMessage;

  TabPage<T> copyWith({
    LoadStatus? status,
    List<T>? items,
    int? page,
    bool? hasNextPage,
    String? errorMessage,
  }) {
    return TabPage<T>(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      errorMessage: errorMessage,
    );
  }
}

class SearchState {
  const SearchState({
    this.query = '',
    this.tab = SearchTab.anime,
    this.animeSort = MediaSort.popularity,
    this.anime = const TabPage<Media>(),
    this.studios = const TabPage<SearchStudio>(),
    this.staff = const TabPage<SearchStaff>(),
    this.characters = const TabPage<SearchCharacter>(),
  });

  final String query;
  final SearchTab tab;
  final MediaSort animeSort;
  final TabPage<Media> anime;
  final TabPage<SearchStudio> studios;
  final TabPage<SearchStaff> staff;
  final TabPage<SearchCharacter> characters;

  /// Backwards-compatible view of the active anime search.
  MediaType? get typeFilter => MediaType.anime;
  LoadStatus get status => anime.status;
  List<Media> get results => anime.items;
  String? get errorMessage => anime.errorMessage;

  /// True once a search has run (used to decide empty vs. prompt states).
  bool get hasSearched =>
      status != LoadStatus.initial && query.trim().isNotEmpty;

  SearchState copyWith({
    String? query,
    SearchTab? tab,
    MediaSort? animeSort,
    TabPage<Media>? anime,
    TabPage<SearchStudio>? studios,
    TabPage<SearchStaff>? staff,
    TabPage<SearchCharacter>? characters,
  }) {
    return SearchState(
      query: query ?? this.query,
      tab: tab ?? this.tab,
      animeSort: animeSort ?? this.animeSort,
      anime: anime ?? this.anime,
      studios: studios ?? this.studios,
      staff: staff ?? this.staff,
      characters: characters ?? this.characters,
    );
  }
}

/// Tabbed search across anime, studios, staff, and characters.
///
/// Each tab keeps its own paged result set. A monotonic [_searchId] per tab
/// discards stale responses when the user types quickly or flips pages
/// mid-flight. The debounce [Timer] is cancelled and nulled on dispose.
class SearchController extends Notifier<SearchState> {
  static const Duration _debounce = Duration(milliseconds: 400);
  static const int _animePerPage = 18;
  static const int _peoplePerPage = 16;

  Timer? _timer;
  final Map<SearchTab, int> _searchIds = {};

  MediaRepository get _repo => ref.read(mediaRepositoryProvider);

  int _nextId(SearchTab tab) => _searchIds[tab] = (_searchIds[tab] ?? 0) + 1;

  @override
  SearchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    Future.microtask(_loadInitial);
    return const SearchState();
  }

  void _loadInitial() {
    runSearch();
  }

  /// Called on every keystroke; the actual request fires after a pause.
  void onQueryChanged(String value) {
    state = state.copyWith(query: value);
    _timer?.cancel();
    if (value.trim().isEmpty) {
      // Empty query shows the ranking (Page 1) for the active tab.
      _resetActivePage();
      unawaited(runSearch());
      return;
    }
    _timer = Timer(_debounce, () {
      _timer = null;
      _resetActivePage();
      unawaited(runSearch());
    });
  }

  void _resetActivePage() {
    switch (state.tab) {
      case SearchTab.anime:
        state = state.copyWith(
          anime: state.anime.copyWith(page: 1, hasNextPage: false),
        );
      case SearchTab.studios:
        state = state.copyWith(
          studios: state.studios.copyWith(page: 1, hasNextPage: false),
        );
      case SearchTab.staff:
        state = state.copyWith(
          staff: state.staff.copyWith(page: 1, hasNextPage: false),
        );
      case SearchTab.characters:
        state = state.copyWith(
          characters:
              state.characters.copyWith(page: 1, hasNextPage: false),
        );
    }
  }

  Future<void> setTab(SearchTab tab) async {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab);
    final needsLoad = switch (tab) {
      SearchTab.anime => state.anime.status == LoadStatus.initial,
      SearchTab.studios => state.studios.status == LoadStatus.initial,
      SearchTab.staff => state.staff.status == LoadStatus.initial,
      SearchTab.characters =>
        state.characters.status == LoadStatus.initial,
    };
    if (needsLoad) await runSearch();
  }

  /// Backwards-compatible type filter: maps onto the tab bar.
  Future<void> setTypeFilter(MediaType? type) async {
    await setTab(SearchTab.anime);
  }

  Future<void> setAnimeSort(MediaSort sort) async {
    if (state.animeSort == sort) return;
    state = state.copyWith(
      animeSort: sort,
      anime: state.anime.copyWith(page: 1, hasNextPage: false),
    );
    await runSearch();
  }

  Future<void> submit(String value) async {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(query: value);
    _resetActivePage();
    await runSearch();
  }

  Future<void> nextPage() async {
    switch (state.tab) {
      case SearchTab.anime:
        if (!state.anime.hasNextPage ||
            state.anime.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          anime: state.anime.copyWith(page: state.anime.page + 1),
        );
      case SearchTab.studios:
        if (!state.studios.hasNextPage ||
            state.studios.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          studios: state.studios.copyWith(page: state.studios.page + 1),
        );
      case SearchTab.staff:
        if (!state.staff.hasNextPage ||
            state.staff.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          staff: state.staff.copyWith(page: state.staff.page + 1),
        );
      case SearchTab.characters:
        if (!state.characters.hasNextPage ||
            state.characters.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          characters: state.characters.copyWith(
            page: state.characters.page + 1,
          ),
        );
    }
    await runSearch();
  }

  Future<void> previousPage() async {
    switch (state.tab) {
      case SearchTab.anime:
        if (state.anime.page <= 1 ||
            state.anime.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          anime: state.anime.copyWith(page: state.anime.page - 1),
        );
      case SearchTab.studios:
        if (state.studios.page <= 1 ||
            state.studios.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          studios: state.studios.copyWith(page: state.studios.page - 1),
        );
      case SearchTab.staff:
        if (state.staff.page <= 1 ||
            state.staff.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          staff: state.staff.copyWith(page: state.staff.page - 1),
        );
      case SearchTab.characters:
        if (state.characters.page <= 1 ||
            state.characters.status == LoadStatus.loading) {
          return;
        }
        state = state.copyWith(
          characters: state.characters.copyWith(
            page: state.characters.page - 1,
          ),
        );
    }
    await runSearch();
  }

  Future<void> runSearch() => switch (state.tab) {
        SearchTab.anime => _runAnime(),
        SearchTab.studios => _runStudios(),
        SearchTab.staff => _runStaff(),
        SearchTab.characters => _runCharacters(),
      };

  Future<void> _runAnime() async {
    final id = _nextId(SearchTab.anime);
    final query = state.query.trim();
    state = state.copyWith(
      anime: state.anime.copyWith(
        status: LoadStatus.loading,
        errorMessage: null,
      ),
    );
    try {
      final result = await _repo.browse(
        BrowseQuery(
          type: MediaType.anime,
          sort: state.animeSort,
          search: query,
          page: state.anime.page,
          perPage: _animePerPage,
        ),
      );
      if ((_searchIds[SearchTab.anime] ?? 0) != id) return;
      state = state.copyWith(
        anime: state.anime.copyWith(
          status: LoadStatus.success,
          items: result.items,
          page: result.page,
          hasNextPage: result.hasNextPage,
          errorMessage: null,
        ),
      );
    } on AppException catch (error) {
      if ((_searchIds[SearchTab.anime] ?? 0) != id) return;
      state = state.copyWith(
        anime: state.anime.copyWith(
          status: LoadStatus.error,
          errorMessage: error.userMessage,
        ),
      );
    } catch (error) {
      if ((_searchIds[SearchTab.anime] ?? 0) != id) return;
      state = state.copyWith(
        anime: state.anime.copyWith(
          status: LoadStatus.error,
          errorMessage: 'Search failed: $error',
        ),
      );
    }
  }

  Future<void> _runStudios() async {
    final id = _nextId(SearchTab.studios);
    state = state.copyWith(
      studios: state.studios.copyWith(
        status: LoadStatus.loading,
        errorMessage: null,
      ),
    );
    try {
      final result = await _repo.searchStudios(
        search: state.query,
        page: state.studios.page,
        perPage: _peoplePerPage,
      );
      if ((_searchIds[SearchTab.studios] ?? 0) != id) return;
      state = state.copyWith(
        studios: state.studios.copyWith(
          status: LoadStatus.success,
          items: result.items,
          page: result.page,
          hasNextPage: result.hasNextPage,
          errorMessage: null,
        ),
      );
    } on AppException catch (error) {
      if ((_searchIds[SearchTab.studios] ?? 0) != id) return;
      state = state.copyWith(
        studios: state.studios.copyWith(
          status: LoadStatus.error,
          errorMessage: error.userMessage,
        ),
      );
    } catch (error) {
      if ((_searchIds[SearchTab.studios] ?? 0) != id) return;
      state = state.copyWith(
        studios: state.studios.copyWith(
          status: LoadStatus.error,
          errorMessage: 'Search failed: $error',
        ),
      );
    }
  }

  Future<void> _runStaff() async {
    final id = _nextId(SearchTab.staff);
    state = state.copyWith(
      staff: state.staff.copyWith(
        status: LoadStatus.loading,
        errorMessage: null,
      ),
    );
    try {
      final result = await _repo.searchStaff(
        search: state.query,
        page: state.staff.page,
        perPage: _peoplePerPage,
      );
      if ((_searchIds[SearchTab.staff] ?? 0) != id) return;
      state = state.copyWith(
        staff: state.staff.copyWith(
          status: LoadStatus.success,
          items: result.items,
          page: result.page,
          hasNextPage: result.hasNextPage,
          errorMessage: null,
        ),
      );
    } on AppException catch (error) {
      if ((_searchIds[SearchTab.staff] ?? 0) != id) return;
      state = state.copyWith(
        staff: state.staff.copyWith(
          status: LoadStatus.error,
          errorMessage: error.userMessage,
        ),
      );
    } catch (error) {
      if ((_searchIds[SearchTab.staff] ?? 0) != id) return;
      state = state.copyWith(
        staff: state.staff.copyWith(
          status: LoadStatus.error,
          errorMessage: 'Search failed: $error',
        ),
      );
    }
  }

  Future<void> _runCharacters() async {
    final id = _nextId(SearchTab.characters);
    state = state.copyWith(
      characters: state.characters.copyWith(
        status: LoadStatus.loading,
        errorMessage: null,
      ),
    );
    try {
      final result = await _repo.searchCharacters(
        search: state.query,
        page: state.characters.page,
        perPage: _peoplePerPage,
      );
      if ((_searchIds[SearchTab.characters] ?? 0) != id) return;
      state = state.copyWith(
        characters: state.characters.copyWith(
          status: LoadStatus.success,
          items: result.items,
          page: result.page,
          hasNextPage: result.hasNextPage,
          errorMessage: null,
        ),
      );
    } on AppException catch (error) {
      if ((_searchIds[SearchTab.characters] ?? 0) != id) return;
      state = state.copyWith(
        characters: state.characters.copyWith(
          status: LoadStatus.error,
          errorMessage: error.userMessage,
        ),
      );
    } catch (error) {
      if ((_searchIds[SearchTab.characters] ?? 0) != id) return;
      state = state.copyWith(
        characters: state.characters.copyWith(
          status: LoadStatus.error,
          errorMessage: 'Search failed: $error',
        ),
      );
    }
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _searchIds.updateAll((key, value) => value + 1);
    state = const SearchState();
    unawaited(runSearch());
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
