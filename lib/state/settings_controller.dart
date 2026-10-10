import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// Theme preference persisted to localStorage.
enum ThemePreference { system, light, dark }

/// Loads/stores app-level preferences (theme for now; language and display
/// options are reserved).
class SettingsController extends Notifier<ThemePreference> {
  static const _themeKey = 'dartotsu.theme';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ThemePreference build() {
    final stored = _prefs.getString(_themeKey);
    return ThemePreference.values.firstWhere(
      (p) => p.name == stored,
      orElse: () => ThemePreference.system,
    );
  }

  ThemeMode get themeMode => switch (state) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  Future<void> setThemePreference(ThemePreference preference) async {
    state = preference;
    await _prefs.setString(_themeKey, preference.name);
  }

  Future<void> toggleDark(bool isDark) =>
      setThemePreference(isDark ? ThemePreference.dark : ThemePreference.light);
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, ThemePreference>(
      SettingsController.new,
    );

/// Convenience provider for widgets that only need the resolved ThemeMode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final controller = ref.watch(settingsControllerProvider.notifier);
  return controller.themeMode;
});
