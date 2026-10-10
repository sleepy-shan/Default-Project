import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../state/load_state.dart';

/// Renders loading / error / empty / success states for a [LoadState].
///
/// Every data-driven screen uses this so behaviour stays consistent.
class StateView<T> extends StatelessWidget {
  const StateView({
    required this.state,
    required this.builder,
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.onRetry,
    this.loading,
    super.key,
  });

  final LoadState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final String emptyMessage;
  final String? emptyTitle;
  final IconData emptyIcon;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      LoadStatus.initial || LoadStatus.loading =>
        loading ?? const Center(child: CircularProgressIndicator()),
      LoadStatus.error => ErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: onRetry,
        ),
      LoadStatus.success when state.data == null => EmptyView(
          message: emptyMessage,
          title: emptyTitle,
          icon: emptyIcon,
        ),
      LoadStatus.success => builder(context, state.data as T),
    };
  }
}

/// Error panel with a short explanation and a retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 44,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: Tokens.space12),
              Text(
                'Something went wrong',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.space8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: Tokens.space16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state panel with an optional call to action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.title,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: Tokens.space12),
              Text(
                title ?? 'Nothing here yet',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.space8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Tokens.space16),
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey placeholder tile shown while content loads.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({this.height = 200, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.disabledColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
    );
  }
}

/// Grid of skeleton tiles used as the loading state for poster grids.
class LoadingPosterGrid extends StatelessWidget {
  const LoadingPosterGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = posterColumns(constraints.maxWidth);
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * Tokens.space12) / columns;
        final tileHeight = tileWidth / Tokens.posterAspect + 56;
        return GridView.builder(
          padding: const EdgeInsets.all(Tokens.space16),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: Tokens.space12,
            crossAxisSpacing: Tokens.space12,
            childAspectRatio: tileWidth / tileHeight,
          ),
          itemCount: columns * 2,
          itemBuilder: (context, index) => const SkeletonTile(height: 240),
        );
      },
    );
  }
}

/// Number of poster columns for a given width.
int posterColumns(double width) {
  if (width >= 1600) return 7;
  if (width >= 1360) return 6;
  if (width >= 1080) return 5;
  if (width >= 840) return 4;
  if (width >= 560) return 3;
  return 2;
}
