import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/auth_repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never leave the user on a blank page: surface startup failures in the
  // console and keep going with a degraded (in-memory) start when possible.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    return true; // handled — don't kill the app on background failures.
  };

  // Clean, shareable URLs (/anime instead of /#/anime). Works when the
  // host rewrites unknown paths to index.html — see the README.
  usePathUrlStrategy();

  final prefs = await _loadPreferences();

  // AniList OAuth implicit flow: AniList redirects back to the registered
  // Redirect URL with `#access_token=...`. Capture it once and persist it
  // so the auth provider can validate it on first listen.
  try {
    final redirectToken = parseAccessTokenFromUri(Uri.base);
    if (redirectToken != null && redirectToken.isNotEmpty) {
      await prefs.setString(AniListAuthRepository.tokenKey, redirectToken);
    }
  } on Object catch (error) {
    // Token capture must never block startup (e.g. blocked storage).
    debugPrint('Ignoring OAuth token capture failure: $error');
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const IkigaiApp(),
    ),
  );
}

/// Loads [SharedPreferences], falling back to an in-memory store when the
/// browser blocks storage (private mode, disabled cookies, sandboxed
/// iframe). Without this fallback `main()` would throw before `runApp`,
/// leaving a white screen on the deployed site.
Future<SharedPreferences> _loadPreferences() async {
  try {
    return await SharedPreferences.getInstance();
  } on Object catch (error) {
    debugPrint('SharedPreferences unavailable, using in-memory: $error');
    SharedPreferences.setMockInitialValues(const {});
    return SharedPreferences.getInstance();
  }
}
