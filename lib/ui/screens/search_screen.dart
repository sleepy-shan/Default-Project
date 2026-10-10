import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/models/media.dart';
import '../../state/load_state.dart';
import '../../state/search_controller.dart';
import '../components/media_grid.dart';
import '../components/state_views.dart';

/// Full search page: debounced input + results for anime and manga.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery.trim().isNotEmpty) {
        // Run the search that came from the URL after the first frame.
        ref
            .read(searchControllerProvider.notifier)
            .submit(widget.initialQuery);
      } else {
        // Focus the field so desktop users can type immediately.
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);

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
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  onChanged: controller.onQueryChanged,
                  onSubmitted: controller.submit,
                  decoration: InputDecoration(
                    hintText: 'Search anime, manga, studios…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.query.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              controller.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space16),
          child: Wrap(
            spacing: Tokens.space8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: state.typeFilter == null,
                onSelected: (_) => controller.setTypeFilter(null),
              ),
              ChoiceChip(
                label: const Text('Anime'),
                selected: state.typeFilter == MediaType.anime,
                onSelected: (_) =>
                    controller.setTypeFilter(MediaType.anime),
              ),
              ChoiceChip(
                label: const Text('Manga'),
                selected: state.typeFilter == MediaType.manga,
                onSelected: (_) =>
                    controller.setTypeFilter(MediaType.manga),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space8),
        Expanded(
          child: StateView<List<Media>>(
            state: _toLoadState(state),
            onRetry: controller.runSearch,
            emptyTitle: state.hasSearched ? 'No results' : 'Start typing',
            emptyMessage: state.hasSearched
                ? 'Nothing matched "${state.query.trim()}". '
                    'Try a different spelling or fewer words.'
                : 'Search by title, genre keywords, or romanization — '
                    'for example "frieren" or "mecha".',
            emptyIcon: state.hasSearched ? Icons.search_off : Icons.search,
            loading: const LoadingPosterGrid(),
            builder: (context, results) => MediaGrid(items: results),
          ),
        ),
      ],
    );
  }

  LoadState<List<Media>> _toLoadState(SearchState state) {
    return switch (state.status) {
      LoadStatus.initial => const LoadState(),
      LoadStatus.loading => const LoadState(status: LoadStatus.loading),
      LoadStatus.error => LoadState(
          status: LoadStatus.error,
          errorMessage: state.errorMessage,
        ),
      LoadStatus.success => LoadState(
          status: LoadStatus.success,
          data: state.results,
        ),
    };
  }
}
