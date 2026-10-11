import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../data/models/airing_schedule.dart';
import '../data/repositories/media_repository.dart';
import 'load_state.dart';
import 'media_providers.dart';

/// Airing calendar state: a list of episodes grouped by day is derived in
/// the UI from [items].
class CalendarState {
  const CalendarState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.weekOffset = 0,
    this.errorMessage,
  });

  final LoadStatus status;

  /// The airing episodes for the selected week, ordered by time.
  final List<AiringScheduleItem> items;

  /// 0 = current week, 1 = next week, ...
  final int weekOffset;
  final String? errorMessage;

  CalendarState copyWith({
    LoadStatus? status,
    List<AiringScheduleItem>? items,
    int? weekOffset,
    String? errorMessage,
  }) {
    return CalendarState(
      status: status ?? this.status,
      items: items ?? this.items,
      weekOffset: weekOffset ?? this.weekOffset,
      errorMessage: errorMessage,
    );
  }
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

  Future<void> load() async {
    final id = ++_loadId;
    final keepItems = state.items;
    state = state.copyWith(status: LoadStatus.loading, errorMessage: null);
    // Keep previous items visible during reload (no flash).
    if (keepItems.isNotEmpty) {
      state = state.copyWith(items: keepItems);
    }
    try {
      final start = _weekStart;
      final end = start.add(const Duration(days: 7));
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

  Future<void> nextWeek() async {
    if (state.status == LoadStatus.loading) return; // throttle spam.
    state = state.copyWith(weekOffset: state.weekOffset + 1);
    await load();
  }

  Future<void> previousWeek() async {
    if (state.status == LoadStatus.loading) return;
    state = state.copyWith(weekOffset: state.weekOffset - 1);
    await load();
  }

  Future<void> thisWeek() async {
    if (state.status == LoadStatus.loading && state.weekOffset == 0) return;
    state = state.copyWith(weekOffset: 0);
    await load();
  }
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);
