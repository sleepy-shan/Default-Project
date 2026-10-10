import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/supabase_tracking_repository.dart';
import '../data/repositories/tracking_repository.dart';

/// Overridden at startup with the resolved [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider must be overridden in main()');
});

/// The tracking store used by the whole app.
///
/// - Supabase build: cloud-backed store with per-user RLS.
/// - Default build: local demo store persisted in this browser.
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  if (AppConfig.hasSupabase) {
    return SupabaseTrackingRepository();
  }
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalTrackingRepository(prefs);
});

/// Auth used by the connections/settings screens.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return createAuthRepository();
});
