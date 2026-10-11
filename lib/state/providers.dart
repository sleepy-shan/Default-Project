import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/tracking_repository.dart';

/// Overridden at startup with the resolved [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider must be overridden in main()');
});

/// The tracking store used by the whole app (browser localStorage).
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalTrackingRepository(prefs);
});

/// AniList account backend (OAuth token + Viewer profile).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = createAuthRepository(prefs);
  ref.onDispose(() {
    if (repo is AniListAuthRepository) repo.dispose();
  });
  return repo;
});

/// Current AniList user (null = guest browsing). Restores the saved session
/// on first listen and re-emits on sign-in/sign-out.
final authStateProvider = StreamProvider<AuthUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  try {
    await repo.restore();
  } on Object {
    // Restore failures fall back to guest mode; errors surface on next
    // explicit sign-in attempt instead of breaking the whole app.
  }
  yield repo.currentUser;
  yield* repo.userChanges.skip(1);
});
