import 'package:flutter_test/flutter_test.dart';
import 'package:ikigai_project/data/models/profile_banner.dart';

void main() {
  group('BannerPreset.fromName', () {
    test('resolves known preset names', () {
      expect(BannerPreset.fromName('starfield'), BannerPreset.starfield);
      expect(BannerPreset.fromName('image'), BannerPreset.image);
    });

    test('falls back for null, empty or unknown names', () {
      expect(BannerPreset.fromName(null), BannerPreset.auto);
      expect(BannerPreset.fromName(''), BannerPreset.auto);
      expect(BannerPreset.fromName('nope'), BannerPreset.auto);
      expect(
        BannerPreset.fromName('nope', fallback: BannerPreset.grid),
        BannerPreset.grid,
      );
    });
  });

  group('ProfileBanner', () {
    test('round-trips through JSON', () {
      const banner = ProfileBanner(
        preset: BannerPreset.image,
        imageUrl: 'https://example.com/banner.png',
      );
      final restored = ProfileBanner.fromJson(banner.toJson());
      expect(restored, banner);
      expect(restored.preset, BannerPreset.image);
      expect(restored.imageUrl, 'https://example.com/banner.png');
    });

    test('omits a blank image URL from JSON', () {
      const banner = ProfileBanner(preset: BannerPreset.auto, imageUrl: '  ');
      expect(banner.toJson().containsKey('image_url'), isFalse);
    });

    test('defaults to auto when decoding an empty map', () {
      final restored = ProfileBanner.fromJson(const {});
      expect(restored.preset, BannerPreset.auto);
      expect(restored.imageUrl, isNull);
    });

    test('hasImage is true only for a non-blank image preset', () {
      expect(
        const ProfileBanner(
          preset: BannerPreset.image,
          imageUrl: 'https://example.com/a.png',
        ).hasImage,
        isTrue,
      );
      expect(
        const ProfileBanner(
          preset: BannerPreset.auto,
          imageUrl: 'https://example.com/a.png',
        ).hasImage,
        isFalse,
      );
      expect(
        const ProfileBanner(preset: BannerPreset.image, imageUrl: '  ').hasImage,
        isFalse,
      );
    });

    test('copyWith can set and clear the image URL', () {
      const banner = ProfileBanner(
        preset: BannerPreset.image,
        imageUrl: 'https://example.com/a.png',
      );
      final cleared = banner.copyWith(imageUrl: null);
      expect(cleared.imageUrl, isNull);
      expect(cleared.preset, BannerPreset.image);

      final kept = banner.copyWith(preset: BannerPreset.aurora);
      expect(kept.preset, BannerPreset.aurora);
      expect(kept.imageUrl, 'https://example.com/a.png');
    });
  });
}
