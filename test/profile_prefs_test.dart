import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikigai_project/data/models/account.dart';
import 'package:ikigai_project/data/models/media.dart';
import 'package:ikigai_project/state/profile_prefs.dart';
import 'package:ikigai_project/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Media _media(int id, {MediaType type = MediaType.anime}) => Media(
  id: id,
  type: type,
  title: 'Title $id',
  coverUrl: 'https://example.com/$id.jpg',
  format: MediaFormat.tv,
  seasonYear: 2024,
);

Future<ProviderContainer> _container([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('isValidBannerUrl', () {
    test('accepts http(s) links only', () {
      expect(isValidBannerUrl('https://example.com/a.gif'), isTrue);
      expect(isValidBannerUrl(' http://example.com/a.png '), isTrue);
      expect(isValidBannerUrl('example.com/a.gif'), isFalse);
      expect(isValidBannerUrl('javascript:alert(1)'), isFalse);
      expect(isValidBannerUrl(''), isFalse);
      expect(isValidBannerUrl(null), isFalse);
    });
  });

  group('ProfileBannerController', () {
    test('defaults to the AniList banner', () async {
      final c = await _container();
      expect(c.read(profileBannerProvider).source, BannerSource.anilist);
    });

    test('persists the source and link', () async {
      final c = await _container();
      await c
          .read(profileBannerProvider.notifier)
          .save(BannerSource.custom, url: ' https://example.com/b.gif ');

      final state = c.read(profileBannerProvider);
      expect(state.source, BannerSource.custom);
      expect(state.url, 'https://example.com/b.gif');
      expect(state.hasValidUrl, isTrue);

      // A fresh container reading the same storage sees the saved choice.
      final prefs = c.read(sharedPreferencesProvider);
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(profileBannerProvider).source, BannerSource.custom);
    });

    test('switching source keeps the previously saved link', () async {
      final c = await _container();
      final n = c.read(profileBannerProvider.notifier);
      await n.save(BannerSource.custom, url: 'https://example.com/b.gif');
      await n.save(BannerSource.komorebi);
      expect(c.read(profileBannerProvider).url, 'https://example.com/b.gif');
    });
  });

  group('LocalFavoritesController', () {
    test('toggle adds newest first and removes on second call', () async {
      final c = await _container();
      final n = c.read(localFavoritesProvider.notifier);

      await n.toggle(_media(1));
      await n.toggle(_media(2));
      expect(c.read(localFavoritesProvider).map((f) => f.id), [2, 1]);
      expect(c.read(localFavoritesProvider).first.subtitle, 'TV · 2024');

      await n.toggle(_media(2));
      expect(c.read(localFavoritesProvider).map((f) => f.id), [1]);
    });

    test('anime and manga with the same id are separate favorites', () async {
      final c = await _container();
      final n = c.read(localFavoritesProvider.notifier);
      await n.toggle(_media(7));
      await n.toggle(_media(7, type: MediaType.manga));

      final kinds = c.read(localFavoritesProvider).map((f) => f.kind).toSet();
      expect(kinds, {FavoriteKind.anime, FavoriteKind.manga});
    });

    test('survives a reload and ignores corrupt storage', () async {
      final c = await _container();
      await c.read(localFavoritesProvider.notifier).toggle(_media(5));
      final prefs = c.read(sharedPreferencesProvider);

      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(localFavoritesProvider).single.id, 5);

      final broken = await _container({'ikigai.profile.favorites': '{nope'});
      expect(broken.read(localFavoritesProvider), isEmpty);
    });
  });
}
