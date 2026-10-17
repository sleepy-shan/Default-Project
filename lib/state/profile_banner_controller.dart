import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/profile_banner.dart';
import 'providers.dart';

/// Stores the profile banner choice (a website-only feature, not AniList)
/// in browser localStorage so it survives reloads and follows the browser.
class ProfileBannerController extends Notifier<ProfileBanner> {
  static const String storageKey = 'ikigai.profile.banner';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ProfileBanner build() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const ProfileBanner();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ProfileBanner.fromJson(decoded);
      }
      if (decoded is Map) {
        return ProfileBanner.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on Object {
      // Corrupt entry — fall back to the default banner.
    }
    return const ProfileBanner();
  }

  /// Selects a built-in style. Any previously entered image URL is kept so
  /// the user can switch back to it later.
  Future<void> setPreset(BannerPreset preset) =>
      _save(state.copyWith(preset: preset));

  /// Sets (or clears, with an empty string) the custom image URL. A non-empty
  /// URL also switches the active preset to [BannerPreset.image].
  Future<void> setImageUrl(String url) {
    final clean = url.trim();
    return _save(
      clean.isEmpty
          ? state.copyWith(imageUrl: null)
          : ProfileBanner(preset: BannerPreset.image, imageUrl: clean),
    );
  }

  /// Restores the default (AniList banner, or the aurora for guests).
  Future<void> reset() => _save(const ProfileBanner());

  Future<void> _save(ProfileBanner value) async {
    state = value;
    await _prefs.setString(storageKey, jsonEncode(value.toJson()));
  }
}

final profileBannerControllerProvider =
    NotifierProvider<ProfileBannerController, ProfileBanner>(
      ProfileBannerController.new,
    );
