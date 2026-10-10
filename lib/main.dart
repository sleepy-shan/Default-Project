import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean, shareable URLs (/anime instead of /#/anime). Works when the
  // host rewrites unknown paths to index.html — see the README.
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();

  if (AppConfig.hasSupabase) {
    // Only runs when the build provides a Supabase URL + anon key via
    // --dart-define. Secrets are never embedded in source.
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const DartotsuApp(),
    ),
  );
}
