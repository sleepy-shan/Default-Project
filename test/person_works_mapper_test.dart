import 'package:flutter_test/flutter_test.dart';
import 'package:ikigai_project/data/anilist/anilist_mapper.dart';

Map<String, dynamic> _node(int id, int popularity) => {
  'id': id,
  'type': 'ANIME',
  'popularity': popularity,
  'title': {'romaji': 'Title $id', 'english': null, 'native': null},
  'coverImage': {'large': 'https://example.com/$id.jpg'},
};

void main() {
  studioTests();
  group('AniListMapper.staffWorks', () {
    test('merges voiced + staff credits, de-duplicates and sorts', () {
      final result = AniListMapper.staffWorks({
        'id': 95591,
        'name': {'full': 'Kenjirou Tsuda', 'native': '津田健次郎'},
        'image': {'large': 'https://example.com/p.jpg'},
        'favourites': 20123,
        'primaryOccupations': ['Voice Actor'],
        'characterMedia': {
          'pageInfo': {'currentPage': 1, 'hasNextPage': true},
          'nodes': [_node(1, 100), _node(2, 500), _node(1, 100)],
        },
        'staffMedia': {
          'pageInfo': {'currentPage': 1, 'hasNextPage': false},
          'nodes': [_node(3, 300), _node(2, 500)],
        },
      }, 1);

      expect(result, isNotNull);
      expect(result!.person.nameFull, 'Kenjirou Tsuda');
      expect(result.person.role, 'Voice Actor');
      expect(result.person.favourites, 20123);
      // Unique ids only, most popular first.
      expect(result.works.items.map((m) => m.id), [2, 3, 1]);
      expect(result.works.hasNextPage, isTrue);
    });

    test('returns null when the staff payload is missing', () {
      expect(AniListMapper.staffWorks(null, 1), isNull);
    });
  });

  group('AniListMapper.characterWorks', () {
    test('maps the profile and series list', () {
      final result = AniListMapper.characterWorks({
        'id': 40,
        'name': {'full': 'Luffy Monkey', 'native': 'モンキー・D・ルフィ'},
        'image': {'large': 'https://example.com/l.jpg'},
        'favourites': 36008,
        'media': {
          'pageInfo': {'currentPage': 2, 'hasNextPage': false},
          'nodes': [_node(21, 900), _node(22, 800)],
        },
      }, 2);

      expect(result, isNotNull);
      expect(result!.person.role, isEmpty);
      expect(result.works.items.length, 2);
      expect(result.works.page, 2);
      expect(result.works.hasNextPage, isFalse);
    });
  });
}

void studioTests() {
  group('AniListMapper.studioWorks', () {
    test('maps studio profile and titles', () {
      final result = AniListMapper.studioWorks({
        'id': 569,
        'name': 'MADHOUSE',
        'favourites': 20066,
        'isAnimationStudio': true,
        'media': {
          'pageInfo': {'currentPage': 1, 'hasNextPage': true},
          'nodes': [_node(5, 10), _node(6, 20)],
        },
      }, 1);
      expect(result!.person.nameFull, 'MADHOUSE');
      expect(result.person.role, 'Animation studio');
      expect(result.works.items.map((m) => m.id), [6, 5]);
      expect(result.works.hasNextPage, isTrue);
    });
  });
}

