import 'package:ikigai_project/data/anilist/anilist_mapper.dart';
import 'package:ikigai_project/data/models/media.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sampleMediaJson() => {
  'id': 154587,
  'idMal': 52991,
  'type': 'ANIME',
  'format': 'TV',
  'status': 'RELEASING',
  'season': 'FALL',
  'seasonYear': 2026,
  'episodes': 24,
  'chapters': null,
  'volumes': null,
  'duration': 24,
  'averageScore': 88,
  'meanScore': 87,
  'popularity': 123456,
  'favourites': 2345,
  'source': 'MANGA',
  'countryOfOrigin': 'JP',
  'startDate': {'year': 2026, 'month': 10, 'day': 1},
  'endDate': {'year': 2026, 'month': 3, 'day': null},
  'siteUrl': 'https://anilist.co/anime/154587',
  'title': {
    'romaji': 'Sousou no Frieren 2',
    'english': null,
    'native': '葬送のフリーレン',
  },
  'coverImage': {
    'extraLarge': 'https://img/extra.jpg',
    'large': 'https://img/large.jpg',
    'color': '#abc',
  },
  'bannerImage': 'https://img/banner.jpg',
  'description': 'The journey continues.<br><em>Next arc.</em>',
  'genres': ['Adventure', 'Drama'],
  'tags': [
    {'name': 'Magic', 'rank': 90},
    {'name': 'Elf', 'rank': 80},
  ],
  'nextAiringEpisode': {'episode': 2, 'airingAt': 1790000000},
  'studios': {
    'nodes': [
      {'name': 'Madhouse'},
    ],
  },
};

void main() {
  group('AniListMapper', () {
    test('maps a media payload with English title fallback', () {
      final media = AniListMapper.single(_sampleMediaJson())!;
      expect(media.id, 154587);
      expect(media.type, MediaType.anime);
      expect(media.title, 'Sousou no Frieren 2');
      expect(media.coverUrl, 'https://img/extra.jpg');
      expect(media.format, MediaFormat.tv);
      expect(media.status, MediaStatus.releasing);
      expect(media.season, MediaSeason.fall);
      expect(media.seasonYear, 2026);
      expect(media.episodes, 24);
      expect(media.duration, 24);
      expect(media.averageScore, 88);
      expect(media.popularity, 123456);
      expect(media.studios, ['Madhouse']);
      expect(media.genres, ['Adventure', 'Drama']);
      expect(media.tags.map((t) => t.name), ['Magic', 'Elf']);
      expect(media.nextAiringEpisode?.episode, 2);
      expect(media.startDate, '2026-10-01');
      // Incomplete fuzzy dates stay null.
      expect(media.endDate, isNull);
      expect(media.totalUnits, 24);
      expect(media.hasUnitsBeyond(1), isTrue);
    });

    test('falls back to romaji when English is missing', () {
      final json = _sampleMediaJson();
      json['title'] = {'romaji': 'Romaji Only', 'english': '', 'native': null};
      final media = AniListMapper.single(json)!;
      expect(media.title, 'Romaji Only');
    });

    test('untitled placeholder when no title survives', () {
      final json = _sampleMediaJson();
      json['title'] = {'romaji': null, 'english': null, 'native': null};
      final media = AniListMapper.single(json)!;
      expect(media.title, 'Untitled');
    });

    test('maps relations', () {
      final json = _sampleMediaJson();
      json['relations'] = {
        'edges': [
          {
            'relationType': 'SEQUEL',
            'node': {
              'id': 200,
              'type': 'ANIME',
              'title': {'romaji': 'Sequel', 'english': null, 'native': null},
              'coverImage': {'extraLarge': null, 'large': null},
            },
          },
          {
            'relationType': null,
            'node': {'id': 201, 'type': 'ANIME'},
          },
        ],
      };
      final media = AniListMapper.single(json)!;
      expect(media.relations, hasLength(2));
      expect(media.relations.first.relationType, 'Sequel');
      expect(media.relations.first.media.id, 200);
      expect(media.relations.last.media.title, 'Untitled');
    });

    test('maps recommendations', () {
      final json = _sampleMediaJson();
      json['recommendations'] = {
        'nodes': [
          {
            'mediaRecommendation': {
              'id': 300,
              'type': 'MANGA',
              'title': {'romaji': 'Rec', 'english': null, 'native': null},
              'coverImage': {'extraLarge': null, 'large': null},
            },
          },
          {'mediaRecommendation': null},
        ],
      };
      final media = AniListMapper.single(json)!;
      expect(media.recommendations, hasLength(1));
      expect(media.recommendations.first.type, MediaType.manga);
    });

    test('returns null for unusable payloads', () {
      expect(AniListMapper.single(null), isNull);
      expect(
        AniListMapper.single({
          'title': {'romaji': 'no id'},
        }),
        isNull,
      );
      expect(AniListMapper.mediaList('not a list'), isEmpty);
    });

    test('maps the airing schedule payload', () {
      final items = AniListMapper.airingSchedule([
        {
          'id': 1,
          'episode': 5,
          'airingAt': 1790000000,
          'media': {
            'id': 7,
            'type': 'ANIME',
            'title': {'romaji': 'Air', 'english': null, 'native': null},
            'coverImage': {'extraLarge': null, 'large': 'https://img/l.jpg'},
          },
        },
      ]);
      expect(items, hasLength(1));
      expect(items.first.episode, 5);
      expect(items.first.title, 'Air');
      expect(items.first.coverUrl, 'https://img/l.jpg');
      expect(items.first.mediaType, MediaType.anime);
    });
  });
}

