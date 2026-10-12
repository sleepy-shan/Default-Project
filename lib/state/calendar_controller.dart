import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../data/models/airing_schedule.dart';
import '../data/models/media.dart';
import '../data/repositories/media_repository.dart';
import 'load_state.dart';
import 'media_providers.dart';

/// Which section of the release calendar is visible.
///
/// AniList only provides an hourly airing schedule for anime. Manga has no
/// episode times, so it gets its own tab grouped by `startDate` (date-only).
enum CalendarTab { anime, manga }

/// Airing calendar state: anime episodes grouped by day plus manga releases
/// grouped by start date are derived in the UI from [items]/[mangaItems].
class CalendarState {
  const CalendarState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.mangaStatus = LoadStatus.initial,
    this.mangaItems = const [],
    this.tab = CalendarTab.anime,
    this.weekOffset = 0,
    this.errorMessage,
    this.mangaErrorMessage,
  });

  final LoadStatus status;

  /// The airing episodes for the selected week, ordered by time.
  final List<AiringScheduleItem> items;

  final LoadStatus mangaStatus;

  /// Manga with a `startDate` inside the selected week, ordered by date.
  final List<Media> mangaItems;

  final CalendarTab tab;

  /// 0 = current week, 1 = next week, ...
  final int weekOffset;
  final String? errorMessage;
  final String? mangaErrorMessage;

  CalendarState copyWith({
    LoadStatus? status,
    List<AiringScheduleItem>? items,
    LoadStatus? mangaStatus,
    List<Media>? mangaItems,
    CalendarTab? tab,
    int? weekOffset,
    Object? errorMessage = _keep,
    Object? mangaErrorMessage = _keep,
  }) {
    return CalendarState(
      status: status ?? this.status,
      items: items ?? this.items,
      mangaStatus: mangaStatus ?? this.mangaStatus,
      mangaItems: mangaItems ?? this.mangaItems,
      tab: tab ?? this.tab,
      weekOffset: weekOffset ?? this.weekOffset,
      errorMessage: errorMessage == _keep
          ? this.errorMessage
          : errorMessage as String?,
      mangaErrorMessage: mangaErrorMessage == _keep
          ? this.mangaErrorMessage
          : mangaErrorMessage as String?,
    );
  }

  static const Object _keep = Object();
}

/// Loads the airing schedule for the selected week from AniList.
///
/// Smart state: a monotonic [_loadId] discards out-of-order responses when
/// the user taps prev/next rapidly. While reloading, previous [items] are
/// kept so the list does not flash empty (keep-previous-data).
class CalendarController extends Notifier<CalendarState> {
  MediaRepository get _repo => ref.read(mediaRepositoryProvider);
  int _loadId = 0;

  @override
  CalendarState build() {
    Future.microtask(load);
    return const CalendarState();
  }

  DateTime get _weekStart {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(
      monday.year,
      monday.month,
      monday.day,
    ).add(Duration(days: 7 * state.weekOffset));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  void setTab(CalendarTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab);
    // Lazily load manga the first time its tab is opened.
    if (tab == CalendarTab.manga &&
        state.mangaStatus == LoadStatus.initial &&
        state.mangaItems.isEmpty) {
      loadManga();
    }
  }

  Future<void> load() async {
    await Future.wait([loadAnime(), loadManga()]);
  }

  Future<void> loadAnime() async {
    final id = ++_loadId;
    state = state.copyWith(status: LoadStatus.loading, errorMessage: null);
    try {
      final start = _weekStart;
      final end = _weekEnd;
      final items = await _repo.airingSchedule(
        from: start.millisecondsSinceEpoch ~/ 1000,
        to: end.millisecondsSinceEpoch ~/ 1000,
        perPage: 50,
      );
      if (id != _loadId) return;
      state = state.copyWith(
        status: LoadStatus.success,
        items: items,
        errorMessage: null,
      );
    } on AppException catch (error) {
      if (id != _loadId) return;
      state = state.copyWith(
        status: LoadStatus.error,
        errorMessage: error.userMessage,
      );
    } catch (error) {
      if (id != _loadId) return;
      state = state.copyWith(
        status: LoadStatus.error,
        errorMessage: 'Could not load the schedule: $error',
      );
    }
  }

  /// Manga has no hourly airing schedule on AniList, so the manga tab shows
  /// titles whose `startDate` falls inside the selected week (date-only).
  Future<void> loadManga() async {
    state = state.copyWith(
      mangaStatus: LoadStatus.loading,
      mangaErrorMessage: null,
    );
    try {
      final start = _weekStart;
      final end = _weekEnd;
      final page = await _repo.browse(
        BrowseQuery(
          type: MediaType.manga,
          sort: MediaSort.startDate,
          perPage: 50,
        ),
      );
      final inWeek = page.items.where((m) {
        final date = m.startDate == null
            ? null
            : DateTime.tryParse(m.startDate!);
        if (date == null) return false;
        final day = DateTime(date.year, date.month, date.day);
        return !day.isBefore(start) && day.isBefore(end);
      }).toList()
        ..sort((a, b) => (a.startDate ?? '').compareTo(b.startDate ?? ''));
      state = state.copyWith(
        mangaStatus: LoadStatus.success,
        mangaItems: inWeek,
        mangaErrorMessage: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        mangaStatus: LoadStatus.error,
        mangaErrorMessage: error.userMessage,
      );
    } catch (error) {
      state = state.copyWith(
        mangaStatus: LoadStatus.error,
        mangaErrorMessage: 'Could not load manga releases: $error',
      );
    }
  }

  Future<void> nextWeek() async {
    if (state.status == LoadStatus.loading ||
        state.mangaStatus == LoadStatus.loading) {
      return; // throttle spam.
    }
    state = state.copyWith(weekOffset: state.weekOffset + 1);
    await load();
  }

  Future<void> previousWeek() async {
    if (state.status == LoadStatus.loading ||
        state.mangaStatus == LoadStatus.loading) {
      return;
    }
    state = state.copyWith(weekOffset: state.weekOffset - 1);
    await load();
  }

  Future<void> thisWeek() async {
    if ((state.status == LoadStatus.loading ||
            state.mangaStatus == LoadStatus.loading) &&
        state.weekOffset == 0) {
      return;
    }
    state = state.copyWith(weekOffset: 0);
    await load();
  }
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);
