import 'package:ikigai_project/core/theme/app_theme.dart';
import 'package:ikigai_project/data/models/media.dart';
import 'package:ikigai_project/data/models/media_entry.dart';
import 'package:ikigai_project/state/load_state.dart';
import 'package:ikigai_project/ui/components/progress_editor.dart';
import 'package:ikigai_project/ui/components/state_views.dart';
import 'package:ikigai_project/ui/components/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('ErrorView shows the message and fires retry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _wrap(
        ErrorView(
          message: 'AniList is rate-limiting requests.',
          onRetry: () => retried++,
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOne);
    expect(find.text('AniList is rate-limiting requests.'), findsOne);

    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('EmptyView shows title, message and action', (tester) async {
    await tester.pumpWidget(
      _wrap(
        EmptyView(
          title: 'Your list is empty',
          message: 'Browse to start tracking.',
          icon: Icons.list_alt,
          actionLabel: 'Browse anime',
          onAction: () {},
        ),
      ),
    );

    expect(find.text('Your list is empty'), findsOne);
    expect(find.text('Browse to start tracking.'), findsOne);
    expect(find.text('Browse anime'), findsOne);
  });

  testWidgets('StateView switches between loading, error and data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        StateView<String>(
          state: const LoadState(status: LoadStatus.loading),
          builder: (context, data) => Text('data: $data'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOne);

    await tester.pumpWidget(
      _wrap(
        StateView<String>(
          state: const LoadState(
            status: LoadStatus.error,
            errorMessage: 'boom',
          ),
          builder: (context, data) => Text('data: $data'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('boom'), findsOne);

    await tester.pumpWidget(
      _wrap(
        StateView<String>(
          state: const LoadState(status: LoadStatus.success, data: 'ok'),
          builder: (context, data) => Text('data: $data'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('data: ok'), findsOne);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('StatusBadge shows Reading for manga', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const StatusBadge(status: ListStatus.watching, type: MediaType.manga),
      ),
    );
    expect(find.text('Reading'), findsOne);
  });

  testWidgets('ProgressEditor reports increments and decrements', (
    tester,
  ) async {
    var progress = 2;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => ProgressEditor(
            progress: progress,
            total: 10,
            unit: 'episode',
            onChanged: (value) => setState(() => progress = value),
          ),
        ),
      ),
    );

    expect(find.text('2 / 10 episodes'), findsOne);

    await tester.tap(find.byIcon(Icons.add));

    expect(progress, 3);
    await tester.pump();

    expect(find.text('3 / 10 episodes'), findsOne);
  });
}

