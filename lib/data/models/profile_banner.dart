/// The banner shown behind the profile header.
///
/// This is a website-only feature (unrelated to AniList): the user can pick
/// one of the built-in animated, anime-inspired styles, or fall back to their
/// AniList banner. The choice is stored in the browser.
enum BannerPreset {
  auto('Auto', 'Your AniList banner, or a calm aurora'),
  aurora('Aurora', 'Slow northern-lights drift'),
  sakura('Sakura', 'Drifting cherry-blossom petals'),
  sunset('Sunset', 'Warm anime-sky gradient'),
  ocean('Ocean', 'Rolling deep-sea waves'),
  neon('Neon', 'Night-city neon glow'),
  starfield('Starfield', 'Gentle parallax stars'),
  gradient('Gradient', 'Flowing brand colour sweep'),
  grid('Grid', 'Animated blueprint lines');

  const BannerPreset(this.label, this.description);

  final String label;
  final String description;

  /// Resolves a stored preset name, tolerating removed/renamed values
  /// (for example the old "image" preset falls back to [BannerPreset.auto]).
  static BannerPreset fromName(
    String? name, {
    BannerPreset fallback = BannerPreset.auto,
  }) {
    if (name == null || name.isEmpty) return fallback;
    for (final preset in BannerPreset.values) {
      if (preset.name == name) return preset;
    }
    return fallback;
  }
}

/// A saved banner preference: which [preset] to render.
class ProfileBanner {
  const ProfileBanner({this.preset = BannerPreset.auto});

  final BannerPreset preset;

  ProfileBanner copyWith({BannerPreset? preset}) =>
      ProfileBanner(preset: preset ?? this.preset);

  Map<String, dynamic> toJson() => {'preset': preset.name};

  static ProfileBanner fromJson(Map<String, dynamic> json) => ProfileBanner(
    preset: BannerPreset.fromName(json['preset'] as String?),
  );

  @override
  bool operator ==(Object other) =>
      other is ProfileBanner && other.preset == preset;

  @override
  int get hashCode => preset.hashCode;
}
