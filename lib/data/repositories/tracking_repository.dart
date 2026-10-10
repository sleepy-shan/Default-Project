import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_exception.dart';
import '../models/media.dart';
import '../models/media_entry.dart';

/// Common contract for every tracking backend (local demo, Supabase, and
/// future third-party services such as AniList/MAL/Simkl accounts).
///
/// Keeping this interface small means a new integration can be added
/// without touching UI code.
abstract interface class TrackingRepository {
  /// Streams the user's entries; emits on every mutation.
  Stream<List<MediaEntry>> watchEntries();

  /// Adds a title to the list (or updates it when already tracked).
  ///
  /// Returns the resulting entry.
  Future<MediaEntry> addOrUpdate({
    required Media media,
    required ListStatus status,
    int progress = 0,
    int? score,
    String? notes,
  });

  /// Updates only the status of an existing entry.
  Future<MediaEntry> setStatus(int mediaId, ListStatus status);

  /// Updates progress by an absolute amount.
  Future<MediaEntry> setProgress(int mediaId, int progress);

  /// Increments progress by one unit (e.g. "watched next episode").
  Future<MediaEntry> incrementProgress(int mediaId);

  /// Updates the score (0-10 scale; null clears it).
  Future<MediaEntry> setScore(int mediaId, int? score);

  /// Removes a title from the list entirely.
  Future<void> remove(int mediaId);

  /// Removes every tracked title.
  Future<void> clear();

  /// The user's entry for [mediaId], or null when untracked.
  Future<MediaEntry?> entryFor(int mediaId);
}

/// Storage-backed implementation used when no Supabase project is
/// configured (and for guests).
///
/// Data lives in the browser's localStorage, which is appropriate for
/// preferences and demo state only — never for tokens or private
/// credentials.
class LocalTrackingRepository implements TrackingRepository {
  LocalTrackingRepository(this._prefs);

  static const String _storageKey = 'dartotsu.tracking.v1';

  final SharedPreferences _prefs;
  final _controller = StreamController<List<MediaEntry>>.broadcast();

  @override
  Stream<List<MediaEntry>> watchEntries() async* {
    // Emit the current snapshot first so listeners always get an initial
    // value, then every subsequent mutation.
    yield _readAll();
    yield* _controller.stream;
  }

  @override
  Future<MediaEntry> addOrUpdate({
    required Media media,
    required ListStatus status,
    int progress = 0,
    int? score,
    String? notes,
  }) async {
    final entries = _readAll();
    final now = DateTime.now();
    final index = entries.indexWhere(
      (e) => e.mediaId == media.id && e.type == media.type,
    );

    final safeProgress = media.totalUnits == null
        ? progress
        : progress.clamp(0, media.totalUnits!);

    final MediaEntry entry;
    if (index >= 0) {
      final existing = entries[index];
      entry = existing.copyWith(
        title: media.title,
        coverUrl: media.coverUrl.isEmpty ? existing.coverUrl : media.coverUrl,
        totalUnits: media.totalUnits,
        status: status,
        progress: safeProgress,
        score: score,
        notes: notes ?? existing.notes,
        startedAt: existing.startedAt ?? now,
        completedAt: status == ListStatus.completed
            ? (existing.completedAt ?? now)
            : null,
        updatedAt: now,
      );
      entries[index] = entry;
    } else {
      entry = MediaEntry(
        mediaId: media.id,
        type: media.type,
        title: media.title,
        coverUrl: media.coverUrl,
        totalUnits: media.totalUnits,
        status: status,
        progress: safeProgress,
        score: score,
        notes: notes,
        startedAt: now,
        completedAt: status == ListStatus.completed ? now : null,
        createdAt: now,
        updatedAt: now,
      );
      entries.add(entry);
    }

    await _writeAll(entries);
    return entry;
  }

  @override
  Future<MediaEntry> setStatus(int mediaId, ListStatus status) async {
    return _mutate(mediaId, (entry) {
      final now = DateTime.now();
      return entry.copyWith(
        status: status,
        progress: status == ListStatus.completed && entry.totalUnits != null
            ? entry.totalUnits!
            : entry.progress,
        startedAt: entry.startedAt ?? now,
        completedAt: status == ListStatus.completed ? now : null,
        updatedAt: now,
      );
    });
  }

  @override
  Future<MediaEntry> setProgress(int mediaId, int progress) async {
    return _mutate(mediaId, (entry) {
      final clamped = entry.totalUnits == null
          ? progress.clamp(0, 1 << 30)
          : progress.clamp(0, entry.totalUnits!);
      return entry.copyWith(
        progress: clamped,
        status:
            entry.status == ListStatus.planning &&
                clamped > 0 &&
                entry.status != ListStatus.completed
            ? ListStatus.watching
            : entry.status,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<MediaEntry> incrementProgress(int mediaId) async {
    return _mutate(mediaId, (entry) {
      final next = entry.progress + 1;
      final total = entry.totalUnits;
      final clamped = total == null ? next : next.clamp(0, total);
      return entry.copyWith(
        progress: clamped,
        status: total != null && clamped >= total
            ? ListStatus.completed
            : ListStatus.watching,
        completedAt: total != null && clamped >= total ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<MediaEntry> setScore(int mediaId, int? score) async {
    return _mutate(mediaId, (entry) {
      return entry.copyWith(
        score: score?.clamp(0, 10),
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  Future<void> remove(int mediaId) async {
    final entries = _readAll()..removeWhere((e) => e.mediaId == mediaId);
    await _writeAll(entries);
  }

  @override
  Future<void> clear() => _writeAll(const []);

  @override
  Future<MediaEntry?> entryFor(int mediaId) async {
    final entries = _readAll();
    final index = entries.indexWhere((e) => e.mediaId == mediaId);
    return index >= 0 ? entries[index] : null;
  }

  Future<MediaEntry> _mutate(
    int mediaId,
    MediaEntry Function(MediaEntry entry) transform,
  ) async {
    final entries = _readAll();
    final index = entries.indexWhere((e) => e.mediaId == mediaId);
    if (index < 0) {
      throw const AppException(
        ErrorKind.notFound,
        'That title is not on your list',
      );
    }
    final updated = transform(entries[index]);
    entries[index] = updated;
    await _writeAll(entries);
    return updated;
  }

  List<MediaEntry> _readAll() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MediaEntry.fromJson)
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> _writeAll(List<MediaEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    final ok = await _prefs.setString(_storageKey, encoded);
    if (!ok) {
      throw const AppException(ErrorKind.storage, 'Could not persist entries');
    }
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_readAll());
  }

  void dispose() => _controller.close();
}
