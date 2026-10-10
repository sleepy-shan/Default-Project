import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/media_entry.dart';
import '../../state/load_state.dart';
import '../../state/my_lists_controller.dart';
import '../components/status_badge.dart';
import '../components/state_views.dart';
import '../router/app_router.dart';

/// The user's personal list: filter by status, sort, and edit progress.
class MyListsScreen extends ConsumerWidget {
  const MyListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myListsControllerProvider);
    final controller = ref.read(myListsControllerProvider.notifier);
    final entries = state.visibleEntries;
    final theme = Theme.of(context);

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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My List', style: theme.textTheme.headlineMedium),
                    Text(
                      '${state.entries.length} tracked '
                      '${state.entries.length == 1 ? 'title' : 'titles'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButton<ListsSort>(
                value: state.sort,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                underline: const SizedBox.shrink(),
                items: [
                  for (final sort in ListsSort.values)
                    DropdownMenuItem(value: sort, child: Text(sort.label)),
                ],
                onChanged: (sort) {
                  if (sort != null) controller.setSort(sort);
                },
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16,
            vertical: Tokens.space8,
          ),
          child: Row(
            spacing: Tokens.space8,
            children: [
              for (final filter in ListsFilter.values)
                ChoiceChip(
                  label: Text(
                    '${filter.label} (${state.countFor(filter)})',
                  ),
                  selected: state.filter == filter,
                  onSelected: (_) => controller.setFilter(filter),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (state.status) {
            LoadStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            LoadStatus.error => _ListError(
                message: state.errorMessage ?? 'Could not load your list.',
                onRetry: controller.refresh,
              ),
            LoadStatus.initial =>
              const Center(child: CircularProgressIndicator()),
            LoadStatus.success when entries.isEmpty => state.filter ==
                    ListsFilter.all
                ? _EmptyList()
                : EmptyFilter(
                    onClear: () => controller.setFilter(ListsFilter.all),
                  ),
            LoadStatus.success => MyListBody(entries: entries),
          },
        ),
      ],
    );
  }
}

/// Entry rows with progress steppers and a status menu.
class EntryRow extends ConsumerWidget {
  const EntryRow({required this.entry, super.key});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(myListsControllerProvider.notifier);
    final fraction = entry.fraction;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Tokens.space16,
        vertical: Tokens.space8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: entry.coverUrl == null || entry.coverUrl!.isEmpty
                  ? Container(
                      width: 52,
                      height: 76,
                      color: theme.disabledColor.withValues(alpha: 0.15),
                    )
                  : Image.network(
                      entry.coverUrl!,
                      width: 52,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 52,
                        height: 76,
                        color: theme.disabledColor.withValues(alpha: 0.15),
                      ),
                    ),
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => context.go(
                      Routes.mediaDetail(entry.type, entry.mediaId),
                    ),
                    child: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                  Row(
                    children: [
                      StatusBadge(status: entry.status, type: entry.type),
                      const SizedBox(width: Tokens.space8),
                      Text(
                        '${entry.progress}'
                        '${entry.totalUnits != null ? '/${entry.totalUnits}' : ''}'
                        ' ${entry.unit}s',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (entry.score != null) ...[
                        const SizedBox(width: Tokens.space8),
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Tokens.warning,
                        ),
                        Text(
                          '${entry.score}/10',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                  if (fraction != null) ...[
                    const SizedBox(height: Tokens.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tokens.radiusPill),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                        backgroundColor: theme.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Mark one more ${entry.unit}',
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => controller.incrementProgress(entry.mediaId),
            ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'remove':
                    await _confirmRemove(context, controller, entry);
                  case 'restart':
                    await controller.setProgress(entry.mediaId, 0);
                  case 'complete':
                    await controller.setStatus(
                      entry.mediaId,
                      ListStatus.completed,
                    );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'restart',
                  child: Text('Reset progress'),
                ),
                PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark completed'),
                ),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    MyListsController controller,
    MediaEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from list?'),
        content: Text('"${entry.title}" will no longer be tracked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.remove(entry.mediaId);
    }
  }
}

/// List body rendered as scrollable rows.
class MyListBody extends ConsumerWidget {
  const MyListBody({required this.entries, super.key});

  final List<MediaEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Tokens.space32),
      itemCount: entries.length,
      itemBuilder: (context, index) => EntryRow(entry: entries[index]),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorView(message: message, onRetry: onRetry);
  }
}

class _EmptyList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.format_list_bulleted_outlined,
      title: 'Your list is empty',
      message: 'Browse anime or manga and tap "Add to my list" '
          'to start tracking progress.',
      actionLabel: 'Browse anime',
      onAction: () => context.go(Routes.anime),
    );
  }
}

class EmptyFilter extends StatelessWidget {
  const EmptyFilter({required this.onClear, super.key});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.filter_alt_off_outlined,
      title: 'Nothing in this status',
      message: 'No titles have this status right now.',
      actionLabel: 'Show all titles',
      onAction: onClear,
    );
  }
}
