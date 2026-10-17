/// The banner shown behind the profile header.
///
/// This is a website-only feature (unrelated to AniList): the user can pick
/// one of the built-in animated styles, fall back to their AniList banner, or
/// point at any image URL. The choice is stored in the browser.
enum BannerPreset {
  auto('Auto', 'Your AniList banner, or a calm aurora for guests'),
  aurora('Aurora', 'Slow northern-lights drift'),
  gradient('Gradient', 'Flowing brand colour sweep'),
  starfield('Starfield', 'Gentle parallax stars'),
  grid('Grid', 'Animated blueprint lines'),
  image('Image', 'Use your own image URL');

  const BannerPreset(this.label, this.description);

  final String label;
  final String description;

  /// Resolves a stored preset name, tolerating removed/renamed values.
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

/// A saved banner preference: which [preset] to render and, for
/// [BannerPreset.image], the [imageUrl] to load.
class ProfileBanner {
  const ProfileBanner({this.preset = BannerPreset.auto, this.imageUrl});

  final BannerPreset preset;
  final String? imageUrl;

  /// True when a custom image URL is set and non-blank.
  bool get hasImage =>
      preset == BannerPreset.image && (imageUrl?.trim().isNotEmpty ?? false);

  /// Sentinel so [copyWith] can tell "keep the image" from "clear it".
  static const Object _unset = Object();

  ProfileBanner copyWith({BannerPreset? preset, Object? imageUrl = _unset}) {
    return ProfileBanner(
      preset: preset ?? this.preset,
      imageUrl: identical(imageUrl, _unset)
          ? this.imageUrl
          : imageUrl as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'image_url': imageUrl,
  };

  static ProfileBanner fromJson(Map<String, dynamic> json) {
    return ProfileBanner(
      preset: BannerPreset.fromName(json['preset'] as String?),
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileBanner &&
      other.preset == preset &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(preset, imageUrl);
}
