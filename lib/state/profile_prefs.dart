import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/account.dart';
import '../data/models/media.dart';
import 'providers.dart';

/// Where the profile banner artwork comes from.
enum BannerSource {
  /// The banner set on the user's AniList profile (falls back to komorebi).
  anilist('AniList banner'),

  /// Procedurally animated dappled light — works for guests, no image needed.
  komorebi('Komorebi'),

  /// Any image / GIF / animated WebP link the user pastes in.
  custom('Image link');

  const BannerSource(this.label);

  final String label;
}

class ProfileBannerPrefs {
  const ProfileBannerPrefs({this.source = BannerSource.anilist, this.url});

  final BannerSource source;

  /// Link used when [source] is [BannerSource.custom].
  final String? url;

  /// Whether [url] looks like an https link we can hand to the image loader.
  bool get hasValidUrl => isValidBannerUrl(url);
}

/// Accepts only absolute http(s) links so a typo cannot break the page.
bool isValidBannerUrl(String? value) {
  if (value == null) return false;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'https' || uri.scheme == 'http');
}

/// Persists the banner choice in browser storage.
class ProfileBannerController extends Notifier<ProfileBannerPrefs> {
  static const _sourceKey = 'ikigai.profile.banner.source';
  static const _urlKey = 'ikigai.profile.banner.url';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ProfileBannerPrefs build() {
    final stored = _prefs.getString(_sourceKey);
    return ProfileBannerPrefs(
      source: BannerSource.values.firstWhere(
        (s) => s.name == stored,
        orElse: () => BannerSource.anilist,
      ),
      url: _prefs.getString(_urlKey),
    );
  }

  Future<void> save(BannerSource source, {String? url}) async {
    final clean = url?.trim();
    state = ProfileBannerPrefs(
      source: source,
      url: clean == null || clean.isEmpty ? state.url : clean,
    );
    await _prefs.setString(_sourceKey, source.name);
    if (clean != null && clean.isNotEmpty) {
      await _prefs.setString(_urlKey, clean);
    }
  }
}

final profileBannerProvider =
    NotifierProvider<ProfileBannerController, ProfileBannerPrefs>(
      ProfileBannerController.new,
    );

/// Favorites kept in this browser (heart button on the detail page).
///
/// They are shown on the profile next to the AniList favorites of a signed-in
/// user. Newest first.
class LocalFavoritesController extends Notifier<List<ProfileFavorite>> {
  static const _key = 'ikigai.profile.favorites';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<ProfileFavorite> build() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(ProfileFavorite.fromJson)
          .whereType<ProfileFavorite>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  static FavoriteKind kindOf(MediaType type) =>
      type == MediaType.anime ? FavoriteKind.anime : FavoriteKind.manga;

  bool isFavorite(MediaType type, int id) =>
      state.any((f) => f.kind == kindOf(type) && f.id == id);

  /// Adds [media] to the favorites, or removes it when already there.
  Future<void> toggle(Media media) async {
    final kind = kindOf(media.type);
    final exists = state.any((f) => f.kind == kind && f.id == media.id);
    if (exists) {
      state = [
        for (final f in state)
          if (!(f.kind == kind && f.id == media.id)) f,
      ];
    } else {
      final year =
          media.seasonYear ??
          int.tryParse((media.startDate ?? '').split('-').first);
      final subtitle = [
        if (media.format != MediaFormat.unknown) media.format.label,
        if (year != null) '$year',
      ].join(' · ');
      state = [
        ProfileFavorite(
          id: media.id,
          kind: kind,
          name: media.title,
          imageUrl: media.coverUrl.isEmpty ? null : media.coverUrl,
          subtitle: subtitle.isEmpty ? null : subtitle,
        ),
        ...state,
      ];
    }
    await _prefs.setString(
      _key,
      jsonEncode([for (final f in state) f.toJson()]),
    );
  }
}

final localFavoritesProvider =
    NotifierProvider<LocalFavoritesController, List<ProfileFavorite>>(
      LocalFavoritesController.new,
    );
