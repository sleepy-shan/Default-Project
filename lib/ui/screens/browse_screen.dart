import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/media.dart';
import '../../state/browse_controller.dart';
import '../../state/load_state.dart';
import '../components/media_grid.dart';
import '../components/sliver_headers.dart';
import '../components/state_views.dart';
import 'filters_sheet.dart';

/// Browse screen shared by Anime and Manga (different [type]).
///
/// Single-scrollable sliver version: one [CustomScrollView] owns the scroll,
/// the toolbar scrolls away, active filters stick, and the grid is a true
/// `SliverGrid` — no nested `GridView`, no gesture fights, sticky headers
/// work, and infinite scroll fires from the outer controller (throttled).
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({required this.type, super.key});

  final MediaType type;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  late final ScrollController _controller;
  DateTime _lastEndReached = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final show = _controller.offset > 900;
    if (show != _showTop && mounted) setState(() => _showTop = show);
    final hasMore = ref.read(
      browseControllerProvider(widget.type).select((s) => s.hasNextPage),
    );
    if (!hasMore) return;
    final max = _controller.position.maxScrollExtent;
    if (max > 0 && _controller.offset >= max - 480) {
      final now = DateTime.now();
      if (now.difference(_lastEndReached) >
          const Duration(milliseconds: 500)) {
        _lastEndReached = now;
        ref.read(browseControllerProvider(widget.type).notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = ref.watch(
      browseControllerProvider(widget.type).select((s) => s.query.hasFilters),
    );

    return Stack(
      children: [
        CustomScrollView(
          controller: _controller,
          physics: const SmoothScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Toolbar(
                type: widget.type,
                onFilterTap: () => _openFilters(context, ref),
              ),
            ),
            if (hasFilters)
              SliverPersistentHeader(
                pinned: true,
                delegate: StickyHeaderDelegate(
                  height: 48,
                  child: _ActiveFilters(type: widget.type),
                ),
              ),
            _GridSlivers(type: widget.type),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: BackToTopButton(
            visible: _showTop,
            onPressed: () {
              if (_controller.hasClients) _controller.smoothTo(0);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    final query = ref.read(browseControllerProvider(widget.type)).query;
    final result = await showModalBottomSheet<FilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(initial: query),
    );
    if (result != null && context.mounted) {
      await ref
          .read(browseControllerProvider(widget.type).notifier)
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
}

/// Grid states as slivers: loading skeleton, error, empty, or the grid.
class _GridSlivers extends ConsumerWidget {
  const _GridSlivers({required this.type});

  final MediaType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      browseControllerProvider(type).select((s) => s.status),
    );
    final items = ref.watch(
      browseControllerProvider(type).select((s) => s.items),
    );
    final hasNextPage = ref.watch(
      browseControllerProvider(type).select((s) => s.hasNextPage),
    );
    final errorMessage = ref.watch(
      browseControllerProvider(type).select((s) => s.errorMessage),
    );
    final controller = ref.read(browseControllerProvider(type).notifier);

    return switch (status) {
      LoadStatus.initial => const SliverToBoxAdapter(
        child: LoadingPosterGrid(),
      ),
      LoadStatus.loading when items.isEmpty =>
        const SliverToBoxAdapter(child: LoadingPosterGrid()),
      LoadStatus.loading => SliverPosterGrid(
        items: items,
        hasMore: true,
      ),
      LoadStatus.error when items.isEmpty => SliverError(
        message: errorMessage ?? 'Could not load titles.',
        onRetry: controller.retry,
      ),
      // Keep-previous-data: error with cached items still shows the grid.
      LoadStatus.error => SliverPosterGrid(
        items: items,
        hasMore: hasNextPage,
      ),
      LoadStatus.success when items.isEmpty => SliverEmpty(
        title: 'No results',
        message:
            'No ${type.label.toLowerCase()} match these filters. '
            'Try widening your search.',
        icon: Icons.search_off,
      ),
      LoadStatus.success => SliverPosterGrid(
        items: items,
        hasMore: hasNextPage,
      ),
    };
  }
}

/// Title, sort control and the filter button.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.type, required this.onFilterTap});

  final MediaType type;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isManga = type == MediaType.manga;
    final sort = ref.watch(
      browseControllerProvider(type).select((s) => s.query.sort),
    );
    final hasFilters = ref.watch(
      browseControllerProvider(type).select((s) => s.query.hasFilters),
    );
    final count = ref.watch(
      browseControllerProvider(type).select((s) => s.items.length),
    );
    final hasMore = ref.watch(
      browseControllerProvider(type).select((s) => s.hasNextPage),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: Tokens.brandGradient,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: Tokens.space8),
            Text(
              isManga ? 'Manga' : 'Anime',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: Tokens.space8),
            AnimatedSwitcher(
              duration: Tokens.durationFast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Container(
                key: ValueKey('$count:$hasMore'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: Tokens.brandGradient,
                  borderRadius: BorderRadius.circular(Tokens.radiusPill),
                ),
                child: Text(
                  '$count${hasMore ? '+' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: Text(
            'Discover ${isManga ? 'series and chapters' : 'shows and movies'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    final controls = Wrap(
      spacing: Tokens.space8,
      runSpacing: Tokens.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: DropdownButton<MediaSort>(
            value: sort,
            isExpanded: true,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            underline: const SizedBox.shrink(),
            items: [
              for (final s in MediaSort.values)
                DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (s) {
              if (s != null) {
                ref.read(browseControllerProvider(type).notifier).setSort(s);
              }
            },
          ),
        ),
        // Animated filter button: gradient + glow fade in when active.
        AnimatedContainer(
          duration: Tokens.durationMedium,
          curve: Tokens.curveSmooth,
          decoration: BoxDecoration(
            gradient: hasFilters ? Tokens.brandGradient : null,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
            boxShadow: hasFilters
                ? Tokens.glowShadow(theme.colorScheme.primary)
                : null,
          ),
          child: hasFilters
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onFilterTap,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filters •'),
                )
              : OutlinedButton.icon(
                  onPressed: onFilterTap,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filters'),
                ),
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

/// Removable chips summarising the active filters (sticky).
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.type});

  final MediaType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(
      browseControllerProvider(type).select((s) => s.query),
    );
    final controller = ref.read(browseControllerProvider(type).notifier);

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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16,
        vertical: Tokens.space8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(spacing: Tokens.space8, children: chips),
      ),
    );
  }
}
