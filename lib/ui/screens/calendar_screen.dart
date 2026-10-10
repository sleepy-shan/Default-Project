import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/airing_schedule.dart';
import '../../state/calendar_controller.dart';
import '../../state/load_state.dart';
import '../components/state_views.dart';
import '../router/app_router.dart';

/// Weekly airing calendar built from AniList's airing schedule.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    final theme = Theme.of(context);

    final monday = _mondayOf(DateTime.now())
        .add(Duration(days: 7 * state.weekOffset));
    final sunday = monday.add(const Duration(days: 6));
    final rangeLabel =
        '${DateFormat.MMMd().format(monday)} – ${DateFormat.MMMd().format(sunday)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16,
            Tokens.space20,
            Tokens.space16,
            Tokens.space8,
          ),
          child: Wrap(
            spacing: Tokens.space8,
            runSpacing: Tokens.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Airing calendar', style: theme.textTheme.headlineMedium),
              Text(
                rangeLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Previous week',
                onPressed: controller.previousWeek,
                icon: const Icon(Icons.chevron_left),
              ),
              OutlinedButton(
                onPressed: controller.thisWeek,
                child: const Text('This week'),
              ),
              IconButton.filledTonal(
                tooltip: 'Next week',
                onPressed: controller.nextWeek,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(
          child: StateView<List<AiringScheduleItem>>(
            state: _state(state),
            emptyTitle: 'Nothing airing this week',
            emptyMessage:
                'AniList has no scheduled episodes for this week yet. '
                'Try another week — the schedule usually updates ahead of time.',
            emptyIcon: Icons.event_busy_outlined,
            onRetry: controller.load,
            loading: const Center(child: CircularProgressIndicator()),
            builder: (context, items) => _ScheduleList(items: items),
          ),
        ),
      ],
    );
  }

  DateTime _mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  LoadState<List<AiringScheduleItem>> _state(CalendarState state) {
    return switch (state.status) {
      LoadStatus.initial => const LoadState(),
      LoadStatus.loading => const LoadState(status: LoadStatus.loading),
      LoadStatus.error => LoadState(
          status: LoadStatus.error,
          errorMessage: state.errorMessage,
        ),
      LoadStatus.success => LoadState(
          status: LoadStatus.success,
          data: state.items,
        ),
    };
  }
}

/// Groups episodes by day and renders each group as a section.
class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.items});

  final List<AiringScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = <String, List<AiringScheduleItem>>{};
    for (final item in items) {
      final date = DateTime.fromMillisecondsSinceEpoch(item.airingAt * 1000);
      final key = DateFormat('yyyy-MM-dd').format(date);
      days.putIfAbsent(key, () => []).add(item);
    }
    final keys = days.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Tokens.space32),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final dayItems = days[key]!;
        final date = DateTime.parse(key);
        final isToday = _isSameDay(date, DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: isToday
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(
                Tokens.space16,
                Tokens.space12,
                Tokens.space16,
                Tokens.space8,
              ),
              child: Text(
                DateFormat('EEEE, MMM d').format(date) +
                    (isToday ? ' • Today' : ''),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isToday ? theme.colorScheme.primary : null,
                ),
              ),
            ),
            for (final item in dayItems) _ScheduleRow(item: item),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item});

  final AiringScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat('HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(item.airingAt * 1000));

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
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space8,
          vertical: Tokens.space2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
        ),
        child: Text(
          'EP ${item.episode}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      onTap: () => context.go(
        Routes.mediaDetail(item.mediaType, item.mediaId),
      ),
    );
  }
}
