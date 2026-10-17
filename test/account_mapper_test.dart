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

    test('maps every list-status bucket and the favourites total', () {
      final profile = AniListMapper.viewerProfile({
        'name': 'Aya',
        'favourites': {
          'anime': {
            'pageInfo': {'total': 17},
          },
        },
        'statistics': {
          'anime': {
            'count': 120,
            'statuses': [
              {'status': 'CURRENT', 'count': 4},
              {'status': 'COMPLETED', 'count': 60},
              {'status': 'PLANNING', 'count': 40},
              {'status': 'PAUSED', 'count': 3},
              {'status': 'DROPPED', 'count': 8},
              {'status': 'REPEATING', 'count': 5},
            ],
          },
        },
      });

      expect(profile!.totalCount, 120);
      expect(profile.watching, 4);
      expect(profile.completed, 60);
      expect(profile.planning, 40);
      expect(profile.paused, 3);
      expect(profile.dropped, 8);
      expect(profile.rewatching, 5);
      expect(profile.favourites, 17);
    });

    test('tolerates missing statistics', () {
      final profile = AniListMapper.viewerProfile({'name': 'Aya'});
      expect(profile!.watching, 0);
      expect(profile.completed, 0);
      expect(profile.rewatching, 0);
      expect(profile.favourites, 0);
      expect(profile.episodesWatched, isNull);
    });

    test('drops a blank banner image and requires a name', () {
      final blank = AniListMapper.viewerProfile({
        'name': 'Aya',
        'bannerImage': '   ',
      });
      expect(blank!.bannerUrl, isNull);
      expect(AniListMapper.viewerProfile({'name': ''}), isNull);
      expect(AniListMapper.viewerProfile(null), isNull);
    });

    test('reads manga statistics, minutes watched and top genres', () {
      final profile = AniListMapper.viewerProfile({
        'name': 'Aya',
        'statistics': {
          'anime': {
            'count': 10,
            'episodesWatched': 120,
            'minutesWatched': 2880,
            'meanScore': 80,
            'genres': [
              {'genre': 'Action', 'count': 6},
              {'genre': 'Comedy', 'count': 3},
            ],
          },
          'manga': {
            'count': 4,
            'chaptersRead': 210,
            'volumesRead': 22,
            'meanScore': 75.5,
            'genres': [
              {'genre': 'Action', 'count': 2},
              {'genre': 'Romance', 'count': 1},
            ],
          },
        },
      });

      expect(profile!.mangaCount, 4);
      expect(profile.chaptersRead, 210);
      expect(profile.volumesRead, 22);
      expect(profile.mangaMeanScore, 75.5);
      expect(profile.minutesWatched, 2880);
      expect(profile.daysWatched, 2);
      // Merged across anime + manga: Action 6+2, then Comedy 3, Romance 1.
      expect(
        profile.topGenres.map((g) => g.genre).toList(),
        ['Action', 'Comedy', 'Romance'],
      );
      expect(profile.topGenres.first.count, 8);
    });

    test('leaves manga metrics null when absent', () {
      final profile = AniListMapper.viewerProfile({'name': 'Aya'});
      expect(profile!.mangaCount, 0);
      expect(profile.chaptersRead, isNull);
      expect(profile.daysWatched, isNull);
      expect(profile.topGenres, isEmpty);
    });
  });

  group('ProfileSection', () {
    test('resolves names and counts from the viewer profile', () {
      const profile = ViewerProfile(
        name: 'Aya',
        totalCount: 100,
        watching: 1,
        completed: 2,
        planning: 3,
        paused: 4,
        dropped: 5,
        rewatching: 6,
        favourites: 7,
      );

      expect(ProfileSection.fromName('watching'), ProfileSection.watching);
      expect(ProfileSection.fromName('favourites'), ProfileSection.favourites);
      expect(ProfileSection.fromName('nope'), ProfileSection.all);
      expect(ProfileSection.fromName(null), ProfileSection.all);
      expect(ProfileSection.all.countIn(profile), 100);
      expect(ProfileSection.completed.countIn(profile), 2);
      expect(ProfileSection.rewatching.countIn(profile), 6);
      expect(ProfileSection.favourites.countIn(profile), 7);
      expect(ProfileSection.all.countIn(null), 0);
    });

    test('carries AniList status wire values', () {
      expect(ProfileSection.watching.status, 'CURRENT');
      expect(ProfileSection.rewatching.status, 'REPEATING');
      expect(ProfileSection.all.status, isNull);
      expect(ProfileSection.favourites.favouritesOnly, isTrue);
      expect(ProfileSection.completed.favouritesOnly, isFalse);
    });
  });

  group('AniListMapper.accountListEntries', () {
    test('flattens status groups, newest update first', () {
      final entries = AniListMapper.accountListEntries({
        'lists': [
          {
            'name': 'Watching',
            'entries': [
              {
                'status': 'CURRENT',
                'progress': 5,
                'updatedAt': 100,
                'media': _media(1),
              },
              {
                'status': 'CURRENT',
                'progress': 9,
                'updatedAt': 300,
                'media': _media(2),
              },
            ],
          },
          {
            'name': 'Completed',
            'entries': [
              {
                'status': 'COMPLETED',
                'progress': 12,
                'score': 8.5,
                'updatedAt': 200,
                'media': _media(3),
              },
            ],
          },
        ],
      });

      expect(entries.map((e) => e.media.id).toList(), [2, 3, 1]);
      expect(entries.first.progress, 9);
      expect(entries.first.updatedAt!.millisecondsSinceEpoch, 300000);
      expect(entries[1].status, 'COMPLETED');
      expect(entries[1].score, 8.5);
    });

    test('skips entries without media and tolerates bad payloads', () {
      expect(AniListMapper.accountListEntries(null), isEmpty);
      final entries = AniListMapper.accountListEntries({
        'lists': [
          {
            'entries': [
              {'status': 'CURRENT'},
              'nope',
            ],
          },
        ],
      });
      expect(entries, isEmpty);
    });
  });

  group('AniListMapper.favouriteAnime', () {
    test('reads nodes and page info', () {
      final page = AniListMapper.favouriteAnime({
        'favourites': {
          'anime': {
            'pageInfo': {'currentPage': 2, 'hasNextPage': true},
            'nodes': [_media(1), _media(2)],
          },
        },
      }, 1);

      expect(page.items.map((m) => m.id).toList(), [1, 2]);
      expect(page.page, 2);
      expect(page.hasNextPage, isTrue);
    });

    test('is empty without a favourites payload', () {
      expect(AniListMapper.favouriteAnime(null, 1).items, isEmpty);
    });
  });

  group('AniListMapper.activities', () {
    test('maps list, text and message activities', () {
      final items = AniListMapper.activities({
        'activities': [
          {
            'id': 1,
            'type': 'ANIME_LIST',
            'status': 'CURRENT',
            'progress': '5',
            'createdAt': 1700000000,
            'media': _media(9),
          },
          {'id': 2, 'type': 'TEXT', 'text': 'Hello world', 'createdAt': 1700000100},
          {
            'id': 3,
            'type': 'MESSAGE',
            'message': 'Hi there',
            'createdAt': 1700000200,
          },
        ],
      });

      expect(items.length, 3);
      expect(items[0].kind, ActivityKind.listUpdate);
      expect(items[0].status, 'CURRENT');
      expect(items[0].progress, 5);
      expect(items[0].mediaId, 9);
      expect(items[1].kind, ActivityKind.text);
      expect(items[1].text, 'Hello world');
      expect(items[2].kind, ActivityKind.message);
      expect(items[2].text, 'Hi there');
    });

    test('tolerates a missing feed and malformed rows', () {
      expect(AniListMapper.activities(null), isEmpty);
      final items = AniListMapper.activities({
        'activities': [
          {'type': 'TEXT', 'text': 'no id'},
          <String, dynamic>{},
        ],
      });
      expect(items, isEmpty);
    });
  });
}

