import 'package:dartotsu_web/data/models/media.dart';
import 'package:dartotsu_web/data/models/media_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaEntry', () {
    final base = MediaEntry(
      mediaId: 21,
      type: MediaType.anime,
      title: 'Frieren',
      status: ListStatus.watching,
      progress: 3,
      totalUnits: 24,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

    test('serializes to JSON and back', () {
      final restored = MediaEntry.fromJson(base.toJson());
      expect(restored.mediaId, base.mediaId);
      expect(restored.type, MediaType.anime);
      expect(restored.title, base.title);
      expect(restored.status, ListStatus.watching);
      expect(restored.progress, 3);
      expect(restored.totalUnits, 24);
      expect(restored.createdAt, base.createdAt);
    });

    test('fraction is progress over total units', () {
      expect(base.fraction, closeTo(3 / 24, 0.0001));
    });

    test('fraction is null when the total is unknown', () {
      final ongoing = base.copyWith(totalUnits: null);
      expect(ongoing.fraction, isNull);
    });

    test('isComplete depends on status or progress', () {
      expect(base.isComplete, isFalse);
      expect(base.copyWith(status: ListStatus.completed).isComplete, isTrue);
      expect(base.copyWith(progress: 24).isComplete, isTrue);
    });

    test('copyWith keeps previous values for omitted fields', () {
      final updated = base.copyWith(progress: 10);
      expect(updated.progress, 10);
      expect(updated.mediaId, base.mediaId);
      expect(updated.totalUnits, base.totalUnits);
    });
  });

  group('ListStatus', () {
    test('wire values round-trip', () {
      for (final status in ListStatus.values) {
        expect(ListStatus.fromWire(status.wire), status);
      }
    });

    test('labels differ for anime vs manga', () {
      expect(
        ListStatus.watching.labelFor(MediaType.anime),
        'Watching',
      );
      expect(
        ListStatus.watching.labelFor(MediaType.manga),
        'Reading',
      );
      expect(
        ListStatus.completed.labelFor(MediaType.manga),
        'Completed',
      );
    });
  });

  group('Media', () {
    test('totalUnits tracks the media type', () {
      const anime = Media(
        id: 1,
        type: MediaType.anime,
        title: 'A',
        coverUrl: '',
        episodes: 12,
        chapters: null,
      );
      const manga = Media(
        id: 2,
        type: MediaType.manga,
        title: 'B',
        coverUrl: '',
        episodes: null,
        chapters: 40,
      );
      expect(anime.totalUnits, 12);
      expect(manga.totalUnits, 40);
    });

    test('hasUnitsBeyond flags unwatched units', () {
      const media = Media(
        id: 1,
        type: MediaType.anime,
        title: 'A',
        coverUrl: '',
        episodes: 2,
      );
      expect(media.hasUnitsBeyond(1), isTrue);
      expect(media.hasUnitsBeyond(2), isFalse);
    });
  });

  group('MediaType', () {
    test('parses wire values case-insensitively', () {
      expect(MediaType.fromWire('ANIME'), MediaType.anime);
      expect(MediaType.fromWire('manga'), MediaType.manga);
      expect(MediaType.fromWire(null), MediaType.anime);
    });

    test('exposes units and verbs', () {
      expect(MediaType.anime.unit, 'episode');
      expect(MediaType.manga.unitPlural, 'chapters');
    });
  });
}
