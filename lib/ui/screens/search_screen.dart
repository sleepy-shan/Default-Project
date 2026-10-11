import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_scroll.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/media.dart';
import '../../state/load_state.dart';
import '../../state/search_controller.dart';
import '../components/media_grid.dart';
import '../components/search_field.dart';
import '../components/sliver_headers.dart';
import '../components/state_views.dart';

/// Full search page: debounced input + results for anime and manga.
///
/// Smart rebuilds: the text field, chips, and results each watch only
/// their slice via `select`, so typing does not rebuild the results grid.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late final ScrollController _scrollController;
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialQuery.trim().isNotEmpty) {
        // Run the search that came from the URL after the first frame.
        ref.read(searchControllerProvider.notifier).submit(widget.initialQuery);
      } else {
        // Focus the field so desktop users can type immediately.
        _focusNode.requestFocus();
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 900;
    if (show != _showTop && mounted) setState(() => _showTop = show);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        widget.initialQuery.trim().isNotEmpty &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery;
      ref.read(searchControllerProvider.notifier).submit(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Single scrollable: search field + chips scroll away, results are a
    // true SliverGrid. Back-to-top overlays via Stack.
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const SmoothScrollPhysics(),
          slivers: const [
            SliverToBoxAdapter(child: _SearchInput()),
            SliverToBoxAdapter(child: _TypeFilterChips()),
            SliverToBoxAdapter(
              child: SizedBox(height: Tokens.space8),
            ),
            _ResultsSlivers(),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: BackToTopButton(
            visible: _showTop,
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.smoothTo(0);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Search-page field: the shared lens design with a clear-X swap-in.
///
/// Uses the same [LensSearchField] as the top bar so colors, halo motion,
/// and text contrast are identical in light and dark mode.
class _SearchInput extends ConsumerWidget {
  const _SearchInput();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasQuery = ref.watch(
      searchControllerProvider.select((s) => s.query.isNotEmpty),
    );
    final controller = ref.read(searchControllerProvider.notifier);
    final parent = context.findAncestorStateOfType<_SearchScreenState>();
    final textController = parent?._controller;
    final focusNode = parent?._focusNode;
    if (textController == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.narrowMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16,
            Tokens.space20,
            Tokens.space16,
            Tokens.space8,
          ),
          child: LensSearchField(
            controller: textController,
            focusNode: focusNode,
            hintLong: 'Search anime, manga, studios…  try "Frieren"',
            hintShort: 'Search anime, manga, studios…',
            showKbdChip: false,
            showClear: hasQuery,
            onClear: () {
              textController.clear();
              controller.clear();
            },
            onChanged: controller.onQueryChanged,
            onSubmitted: controller.submit,
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChips extends ConsumerWidget {
  const _TypeFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter = ref.watch(
      searchControllerProvider.select((s) => s.typeFilter),
    );
    final controller = ref.read(searchControllerProvider.notifier);

    Widget chip(String label, MediaType? value) {
      final selected = typeFilter == value;
      return ChoiceChip(
        label: AnimatedScale(
          scale: selected ? 1.04 : 1.0,
          duration: Tokens.durationFast,
          curve: Tokens.curveSmooth,
          child: Text(label),
        ),
        selected: selected,
        onSelected: (_) => controller.setTypeFilter(value),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.narrowMaxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
          child: Wrap(
            spacing: Tokens.space8,
            runSpacing: Tokens.space8,
            children: [
              chip('All', null),
              chip('Anime', MediaType.anime),
              chip('Manga', MediaType.manga),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsSlivers extends ConsumerWidget {
  const _ResultsSlivers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      searchControllerProvider.select((s) => s.status),
    );
    final query = ref.watch(searchControllerProvider.select((s) => s.query));
    final results = ref.watch(
      searchControllerProvider.select((s) => s.results),
    );
    final errorMessage = ref.watch(
      searchControllerProvider.select((s) => s.errorMessage),
    );
    final controller = ref.read(searchControllerProvider.notifier);
    final hasSearched =
        status != LoadStatus.initial && query.trim().isNotEmpty;

    return switch (status) {
      LoadStatus.initial => SliverEmpty(
        title: 'Start typing',
        message: 'Search by title, genre keywords, or romanization — '
            'for example "frieren" or "mecha".',
        icon: Icons.search,
      ),
      LoadStatus.loading => const SliverToBoxAdapter(
        child: LoadingPosterGrid(),
      ),
      LoadStatus.error => SliverError(
        message: errorMessage ?? 'Search failed.',
        onRetry: controller.runSearch,
      ),
      LoadStatus.success when results.isEmpty => SliverEmpty(
        title: 'No results',
        message: hasSearched
            ? 'Nothing matched "${query.trim()}". '
                  'Try a different spelling or fewer words.'
            : 'Search by title, genre keywords, or romanization.',
        icon: Icons.search_off,
      ),
      LoadStatus.success => SliverPosterGrid(items: results),
    };
  }
}
