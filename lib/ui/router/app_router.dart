import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/media.dart';
import '../layout/app_shell.dart';
import '../screens/about_screen.dart';
import '../screens/browse_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/connections_screen.dart';
import '../screens/home_screen.dart';
import '../screens/my_lists_screen.dart';
import '../screens/media_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';

/// Route paths, kept in one place so links stay consistent.
abstract final class Routes {
  static const home = '/';
  static const anime = '/anime';
  static const manga = '/manga';
  static const calendar = '/calendar';
  static const lists = '/lists';
  static const search = '/search';
  static const connections = '/connections';
  static const settings = '/settings';
  static const about = '/about';

  static String mediaDetail(MediaType type, int id) =>
      '/media/${type.anilistValue.toLowerCase()}/$id';

  static String searchWith(String query) =>
      '$search?q=${Uri.encodeComponent(query)}';
}

/// Builds `'/media/:type/:id'`.
GoRoute mediaDetailRoute() => GoRoute(
  path: '/media/:type/:id',
  builder: (context, state) => MediaDetailScreen(
    mediaId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    initialType: MediaType.fromWire(state.pathParameters['type']),
  ),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // No initialLocation: on the web the router must honor the browser URL
    // so deep links like /anime or /media/anime/21 work on load/reload.
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.anime,
            builder: (context, state) =>
                const BrowseScreen(type: MediaType.anime),
          ),
          GoRoute(
            path: Routes.manga,
            builder: (context, state) =>
                const BrowseScreen(type: MediaType.manga),
          ),
          GoRoute(
            path: Routes.calendar,
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: Routes.lists,
            builder: (context, state) => const MyListsScreen(),
          ),
          GoRoute(
            path: Routes.search,
            builder: (context, state) => SearchScreen(
              initialQuery: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: Routes.connections,
            builder: (context, state) => const ConnectionsScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: Routes.about,
            builder: (context, state) => const AboutScreen(),
          ),
          mediaDetailRoute(),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('That page does not exist.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    ),
  );
});
