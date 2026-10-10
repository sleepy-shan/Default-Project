import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/media.dart';
import '../../state/browse_controller.dart';
import '../../state/load_state.dart';
import '../components/media_grid.dart';
import '../components/state_views.dart';
import 'filters_sheet.dart';

/// Browse screen shared by Anime and Manga (different [type]).
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({required this.type, super.key});

  final MediaType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browseControllerProvider(type));
    final controller = ref.read(browseControllerProvider(type).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          state: state,
          onFilterTap: () => _openFilters(context, ref),
          onClearFilters: controller.clearFilters,
        ),
        if (state.query.hasFilters) _ActiveFilters(state: state),
        Expanded(
          child: StateView<List<Media>>(
            state: _toLoadState(state),
            onRetry: controller.retry,
            emptyMessage:
                'No ${type.label.toLowerCase()} match these filters. '
                'Try widening your search.',
            emptyIcon: Icons.search_off,
            loading: const LoadingPosterGrid(),
            builder: (context, items) => MediaGrid(
              items: items,
              hasMore: state.hasNextPage,
              onEndReached: controller.loadMore,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    final query = ref.read(browseControllerProvider(type)).query;
    final result = await showModalBottomSheet<FilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(initial: query),
    );
    if (result != null) {
      await ref
          .read(browseControllerProvider(type).notifier)
          .applyFilters(
            genre: result.genre,
            status: result.status,
            format: result.format,
            season: result.season,
            seasonYear: result.seasonYear,
            sort: result.sort,
          );
    }
  }

  /// Converts browse state into the load state StateView renders.
  LoadState<List<Media>> _toLoadState(BrowseState state) {
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

/// Title, sort control and the filter button.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.state,
    required this.onFilterTap,
    required this.onClearFilters,
  });

  final BrowseState state;
  final VoidCallback onFilterTap;
  final Future<void> Function() onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isManga = state.query.type == MediaType.manga;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isManga ? 'Manga' : 'Anime',
          style: theme.textTheme.headlineMedium,
        ),
        Text(
          'Discover ${isManga ? 'series and chapters' : 'shows and movies'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<MediaSort>(
          value: state.query.sort,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          underline: const SizedBox.shrink(),
          items: [
            for (final sort in MediaSort.values)
              DropdownMenuItem(value: sort, child: Text(sort.label)),
          ],
          onChanged: (sort) {
            if (sort != null) {
              ref
                  .read(browseControllerProvider(state.query.type).notifier)
                  .setSort(sort);
            }
          },
        ),
        const SizedBox(width: Tokens.space8),
        OutlinedButton.icon(
          onPressed: onFilterTap,
          icon: const Icon(Icons.tune, size: 18),
          label: Text(state.query.hasFilters ? 'Filters •' : 'Filters'),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space20,
        Tokens.space16,
        Tokens.space8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 640) {
            return Row(children: [titleBlock, const Spacer(), controls]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: Tokens.space8),
              Align(alignment: Alignment.centerRight, child: controls),
            ],
          );
        },
      ),
    );
  }
}

/// Removable chips summarising the active filters.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.state});

  final BrowseState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = state.query;
    final controller = ref.read(browseControllerProvider(query.type).notifier);

    // Re-applies every filter except the one being removed.
    Future<void> clear({
      bool withGenre = true,
      bool withStatus = true,
      bool withFormat = true,
      bool withSeason = true,
    }) {
      return controller.applyFilters(
        genre: withGenre ? query.genre : null,
        status: withStatus ? query.status : null,
        format: withFormat ? query.format : null,
        season: withSeason ? query.season : null,
        seasonYear: withSeason ? query.seasonYear : null,
        sort: query.sort,
      );
    }

    final chips = <Widget>[
      if (query.search.trim().isNotEmpty)
        InputChip(
          label: Text('"${query.search.trim()}"'),
          onDeleted: () => controller.setSearch(''),
        ),
      if (query.genre != null && query.genre!.isNotEmpty)
        InputChip(
          label: Text(query.genre!),
          onDeleted: () => clear(withGenre: false),
        ),
      if (query.status != null)
        InputChip(
          label: Text(query.status!.label),
          onDeleted: () => clear(withStatus: false),
        ),
      if (query.format != null)
        InputChip(
          label: Text(query.format!.label),
          onDeleted: () => clear(withFormat: false),
        ),
      if (query.season != null)
        InputChip(
          label: Text(
            query.seasonYear != null
                ? '${query.season!.label} ${query.seasonYear}'
                : query.season!.label,
          ),
          onDeleted: () => clear(withSeason: false),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
      child: Wrap(spacing: Tokens.space8, children: chips),
    );
  }
}
