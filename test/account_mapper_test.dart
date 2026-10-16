import 'package:flutter_test/flutter_test.dart';
import 'package:ikigai_project/data/anilist/anilist_mapper.dart';
import 'package:ikigai_project/data/models/account.dart';

Map<String, dynamic> _media(int id) => {
  'id': id,
  'type': 'ANIME',
  'title': {'romaji': 'Title $id', 'english': null, 'native': null},
  'coverImage': {'large': 'https://example.com/$id.jpg'},
};

void main() {
  group('AniListMapper.notifications', () {
    test('maps airing, related and data-change notifications', () {
      final result = AniListMapper.notifications([
        {
          'id': 1,
          'type': 'AIRING',
          'episode': 5,
          'createdAt': 1760000000,
          'media': _media(10),
        },
        {
          'id': 2,
          'type': 'RELATED_MEDIA_ADDITION',
          'createdAt': 1760000100,
          'media': _media(11),
        },
        {
          'id': 3,
          'type': 'MEDIA_DATA_CHANGE',
          'reason': 'Aired episodes were updated',
          'createdAt': 1760000200,
          'media': _media(12),
        },
      ]);

      expect(result.map((n) => n.kind), [
        NotificationKind.airing,
        NotificationKind.relatedAddition,
        NotificationKind.dataChange,
      ]);
      expect(result[0].message, 'Episode 5 aired');
      expect(result[0].title, 'Title 10');
      expect(result[2].message, 'Aired episodes were updated');
    });

    test('skips unknown types and entries without media', () {
      final result = AniListMapper.notifications([
        {'id': 1, 'type': 'FOLLOWING', 'createdAt': 1, 'media': _media(1)},
        {'id': 2, 'type': 'AIRING', 'episode': 1, 'createdAt': 1},
        <String, dynamic>{},
      ]);
      expect(result, isEmpty);
    });
  });

  group('AniListMapper.viewerProfile', () {
    test('reads name, images and anime statistics', () {
      final profile = AniListMapper.viewerProfile({
        'id': 1,
        'name': 'Aya',
        'avatar': {'large': 'https://example.com/a.png'},
        'bannerImage': 'https://example.com/b.png',
        'statistics': {
          'anime': {
            'count': 40,
            'episodesWatched': 812,
            'meanScore': 78.5,
            'statuses': [
              {'status': 'COMPLETED', 'count': 30},
              {'status': 'CURRENT', 'count': 6},
            ],
          },
        },
      });

      expect(profile, isNotNull);
      expect(profile!.name, 'Aya');
      expect(profile.watching, 6);
      expect(profile.episodesWatched, 812);
      expect(profile.meanScore, 78.5);
      expect(profile.bannerUrl, 'https://example.com/b.png');
    });

    test('tolerates missing statistics', () {
      final profile = AniListMapper.viewerProfile({'name': 'Aya'});
      expect(profile!.watching, 0);
      expect(profile.episodesWatched, isNull);
    });
  });

  group('AniListMapper.viewerProfile favorites', () {
    test('keeps every status count and maps all three favorite kinds', () {
      final profile = AniListMapper.viewerProfile({
        'name': 'Aya',
        'statistics': {
          'anime': {
            'statuses': [
              {'status': 'COMPLETED', 'count': 30},
              {'status': 'REPEATING', 'count': 2},
            ],
          },
        },
        'favourites': {
          'anime': {
            'nodes': [
              {
                'id': 1,
                'format': 'TV',
                'seasonYear': 2019,
                'title': {'romaji': 'Anime One', 'english': null},
                'coverImage': {'large': 'https://example.com/1.jpg'},
              },
            ],
          },
          'manga': {
            'nodes': [
              {
                'id': 2,
                'format': 'MANGA',
                'startDate': {'year': 2005},
                'title': {'romaji': 'Manga Two'},
                'coverImage': {'large': 'https://example.com/2.jpg'},
              },
            ],
          },
          'characters': {
            'nodes': [
              {
                'id': 3,
                'name': {'full': 'Char Three'},
                'image': {'large': 'https://example.com/3.jpg'},
                'media': {
                  'nodes': [
                    {
                      'title': {'romaji': 'Anime One'},
                    },
                  ],
                },
              },
              {'id': 4, 'name': {'full': ''}},
            ],
          },
        },
      });

      expect(profile!.statusCounts['COMPLETED'], 30);
      expect(profile.statusCounts['REPEATING'], 2);
      expect(profile.favorites.map((f) => f.kind), [
        FavoriteKind.anime,
        FavoriteKind.manga,
        FavoriteKind.character,
      ]);
      expect(profile.favorites[0].name, 'Anime One');
      expect(profile.favorites[0].subtitle, 'TV · 2019');
      expect(profile.favorites[1].subtitle, 'Manga · 2005');
      expect(profile.favorites[2].subtitle, 'Anime One');
    });

    test('no favourites block means an empty list', () {
      final profile = AniListMapper.viewerProfile({'name': 'Aya'});
      expect(profile!.favorites, isEmpty);
      expect(profile.statusCounts, isEmpty);
    });
  });
}
