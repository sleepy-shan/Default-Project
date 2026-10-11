import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/airing_schedule.dart';
import '../../state/calendar_controller.dart';
import '../../state/load_state.dart';
import '../components/sliver_headers.dart';
import '../components/state_views.dart';
import '../router/app_router.dart';

/// Hoisted formatters: allocating `DateFormat` per build/row is wasteful.
final _rangeFormat = DateFormat.MMMd();
final _dayKeyFormat = DateFormat('yyyy-MM-dd');
final _dayHeaderFormat = DateFormat('EEEE, MMM d');
final _timeFormat = DateFormat('HH:mm');

/// Weekly airing calendar built from AniList's airing schedule.
///
/// Single-scrollable sliver version: pinned header with title + week
/// controls, schedule as one flattened `SliverList` (day headers + rows).
/// Reloads keep previous items with a thin `SliverToBoxAdapter` progress
/// bar instead of flashing a spinner.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      calendarControllerProvider.select((s) => s.status),
    );
    final isReloading = ref.watch(
      calendarControllerProvider.select(
        (s) => s.status == LoadStatus.loading && s.items.isNotEmpty,
      ),
    );

    return CustomScrollView(
      physics: const SmoothScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _Header()),
        if (isReloading)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        switch (status) {
          LoadStatus.initial || LoadStatus.loading => const _LoadingSlivers(),
          LoadStatus.error => const _ErrorSlivers(),
          LoadStatus.success => const _ScheduleSlivers(),
        },
      ],
    );
  }
}

class _LoadingSlivers extends ConsumerWidget {
  const _LoadingSlivers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasItems = ref.watch(
      calendarControllerProvider.select((s) => s.items.isNotEmpty),
    );
    // Keep-previous-data while reloading.
    if (hasItems) return const _ScheduleSlivers();
    return const SliverToBoxAdapter(child: LoadingListRows(count: 6));
  }
}

class _ErrorSlivers extends ConsumerWidget {
  const _ErrorSlivers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      calendarControllerProvider.select((s) => s.items),
    );
    if (items.isNotEmpty) return const _ScheduleSlivers();
    final message = ref.watch(
      calendarControllerProvider.select(
        (s) => s.errorMessage ?? 'Could not load the schedule.',
      ),
    );
    final controller = ref.read(calendarControllerProvider.notifier);
    return SliverError(message: message, onRetry: controller.load);
  }
}

class _ScheduleSlivers extends ConsumerWidget {
  const _ScheduleSlivers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      calendarControllerProvider.select((s) => s.items),
    );
    if (items.isEmpty) {
      return const SliverEmpty(
        title: 'Nothing airing this week',
        message:
            'AniList has no scheduled episodes for this week yet. '
            'Try another week — the schedule usually updates ahead of time.',
        icon: Icons.event_busy_outlined,
      );
    }
    final rows = _buildRows(items);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: Tokens.space32),
      sliver: SliverList.builder(
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return switch (row) {
            _DayHeader(:final date, :final isToday) => _DayHeaderTile(
              date: date,
              isToday: isToday,
            ),
            _EpisodeRow(:final item) => RepaintBoundary(
              child: _ScheduleRow(item: item),
            ),
          };
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weekOffset = ref.watch(
      calendarControllerProvider.select((s) => s.weekOffset),
    );
    final isLoading = ref.watch(
      calendarControllerProvider.select(
        (s) => s.status == LoadStatus.loading,
      ),
    );
    final controller = ref.read(calendarControllerProvider.notifier);

    final monday = _mondayOf(DateTime.now()).add(
      Duration(days: 7 * weekOffset),
    );
    final sunday = monday.add(const Duration(days: 6));
    final rangeLabel =
        '${_rangeFormat.format(monday)} – ${_rangeFormat.format(sunday)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Airing calendar', style: theme.textTheme.headlineMedium),
              AnimatedSwitcher(
                duration: Tokens.durationMedium,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  rangeLabel,
                  key: ValueKey(rangeLabel),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
          final weekControls = Wrap(
            spacing: Tokens.space8,
            runSpacing: Tokens.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.start,
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous week',
                onPressed: isLoading ? null : controller.previousWeek,
                icon: AnimatedRotation(
                  turns: isLoading ? 0.5 : 0.0,
                  duration: Tokens.durationMedium,
                  curve: Tokens.curveSmooth,
                  child: const Icon(Icons.chevron_left),
                ),
              ),
              OutlinedButton(
                onPressed: isLoading ? null : controller.thisWeek,
                child: const Text('This week'),
              ),
              IconButton.filledTonal(
                tooltip: 'Next week',
                onPressed: isLoading ? null : controller.nextWeek,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          );
          if (constraints.maxWidth >= 640) {
            return Row(children: [titleBlock, const Spacer(), weekControls]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: Tokens.space8),
              weekControls,
            ],
          );
        },
      ),
    );
  }

  DateTime _mondayOf(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }
}

/// Flattened rows shared by the sliver list builder.
List<_Row> _buildRows(List<AiringScheduleItem> items) {
  final days = <String, List<AiringScheduleItem>>{};
  for (final item in items) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.airingAt * 1000);
    final key = _dayKeyFormat.format(date);
    days.putIfAbsent(key, () => []).add(item);
  }
  final keys = days.keys.toList()..sort();
  final now = DateTime.now();
  final rows = <_Row>[];
  for (final key in keys) {
    final dayItems = days[key]!;
    final date = DateTime.parse(key);
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    rows.add(_DayHeader(date, isToday));
    for (final item in dayItems) {
      rows.add(_EpisodeRow(item));
    }
  }
  return rows;
}

sealed class _Row {
  const _Row();
}

class _DayHeader extends _Row {
  const _DayHeader(this.date, this.isToday);

  final DateTime date;
  final bool isToday;
}

class _EpisodeRow extends _Row {
  const _EpisodeRow(this.item);

  final AiringScheduleItem item;
}

class _DayHeaderTile extends StatelessWidget {
  const _DayHeaderTile({required this.date, required this.isToday});

  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      // primaryContainer/onPrimaryContainer keep "Today" legible in both
      // light and dark mode (plain primary on tinted white was too faint).
      color: isToday
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space12,
        Tokens.space16,
        Tokens.space8,
      ),
      child: Text(
        _dayHeaderFormat.format(date) + (isToday ? ' • Today' : ''),
        style: theme.textTheme.titleMedium?.copyWith(
          color: isToday ? scheme.onPrimaryContainer : null,
          fontWeight: isToday ? FontWeight.w800 : null,
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item});

  final AiringScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = _timeFormat.format(
      DateTime.fromMillisecondsSinceEpoch(item.airingAt * 1000),
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16,
        vertical: Tokens.space4,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        child: item.coverUrl == null || item.coverUrl!.isEmpty
            ? Container(
                width: 40,
                height: 56,
                color: theme.disabledColor.withValues(alpha: 0.15),
              )
            : Image.network(
                item.coverUrl!,
                width: 40,
                height: 56,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stack) => Container(
                  width: 40,
                  height: 56,
                  color: theme.disabledColor.withValues(alpha: 0.15),
                ),
              ),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        'Airs at $time • ${Formatters.timeUntil(item.airingAt)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: AnimatedContainer(
        duration: Tokens.durationFast,
        curve: Tokens.curveSmooth,
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space8,
          vertical: Tokens.space2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
        ),
        child: Text(
          'EP ${item.episode}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      onTap: () => context.go(Routes.mediaDetail(item.mediaType, item.mediaId)),
    );
  }
}
