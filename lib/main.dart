import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/auth_repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean, shareable URLs (/anime instead of /#/anime). Works when the
  // host rewrites unknown paths to index.html — see the README.
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();

  // AniList OAuth implicit flow: AniList redirects back to the registered
  // Redirect URL with `#access_token=...`. Capture it once and persist it
  // so the auth provider can validate it on first listen.
  final redirectToken = parseAccessTokenFromUri(Uri.base);
  if (redirectToken != null && redirectToken.isNotEmpty) {
    await prefs.setString(AniListAuthRepository.tokenKey, redirectToken);
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const IkigaiApp(),
    ),
  );
}
