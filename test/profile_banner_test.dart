import 'package:flutter_test/flutter_test.dart';
import 'package:ikigai_project/data/models/profile_banner.dart';

void main() {
  group('BannerPreset.fromName', () {
    test('resolves known preset names', () {
      expect(BannerPreset.fromName('starfield'), BannerPreset.starfield);
      expect(BannerPreset.fromName('sakura'), BannerPreset.sakura);
      expect(BannerPreset.fromName('neon'), BannerPreset.neon);
      expect(BannerPreset.fromName('ocean'), BannerPreset.ocean);
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

    test('migrates the removed image preset to auto', () {
      expect(BannerPreset.fromName('image'), BannerPreset.auto);
    });
  });

  group('ProfileBanner', () {
    test('round-trips through JSON', () {
      const banner = ProfileBanner(preset: BannerPreset.ocean);
      final restored = ProfileBanner.fromJson(banner.toJson());
      expect(restored, banner);
      expect(restored.preset, BannerPreset.ocean);
      expect(banner.toJson(), {'preset': 'ocean'});
    });

    test('defaults to auto when decoding an empty map', () {
      final restored = ProfileBanner.fromJson(const {});
      expect(restored.preset, BannerPreset.auto);
    });

    test('copyWith changes only the preset', () {
      const banner = ProfileBanner(preset: BannerPreset.ocean);
      expect(
        banner.copyWith(preset: BannerPreset.sunset).preset,
        BannerPreset.sunset,
      );
      expect(banner.copyWith().preset, BannerPreset.ocean);
    });

    test('equality is based on the preset', () {
      expect(
        const ProfileBanner(preset: BannerPreset.sakura),
        const ProfileBanner(preset: BannerPreset.sakura),
      );
      expect(
        const ProfileBanner(preset: BannerPreset.sakura) ==
            const ProfileBanner(preset: BannerPreset.neon),
        isFalse,
      );
    });
  });
}
