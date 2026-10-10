import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/app_exception.dart';
import '../models/media.dart';
import '../models/media_entry.dart';
import 'tracking_repository.dart';

/// Supabase-backed tracking store (PostgreSQL + Row Level Security).
///
/// Active only when the app is built with `SUPABASE_URL` and
/// `SUPABASE_ANON_KEY`. Every row is scoped to `auth.uid()` by RLS, so the
/// client only ever reads/writes the signed-in user's own records.
/// See `supabase/schema.sql`.
class SupabaseTrackingRepository implements TrackingRepository {
  SupabaseTrackingRepository();

  static const String table = 'user_media_lists';

  SupabaseClient get _db => Supabase.instance.client;

  String get _userId {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw const AppException(ErrorKind.unauthorized, 'Not signed in');
    }
    return user.id;
  }

  @override
  Stream<List<MediaEntry>> watchEntries() {
    return _db
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<MediaEntry> addOrUpdate({
    required Media media,
    required ListStatus status,
    int progress = 0,
    int? score,
    String? notes,
  }) async {
    final userId = _userId;
    final now = DateTime.now();
    final total = media.totalUnits;
    final safeProgress =
        total == null ? progress : progress.clamp(0, total);

    final existing = await _db
        .from(table)
        .select()
        .eq('user_id', userId)
        .eq('media_id', media.id)
        .eq('media_type', media.type.anilistValue)
        .maybeSingle();

    final Map<String, dynamic> row;
    if (existing == null) {
      row = {
        'user_id': userId,
        'media_id': media.id,
        'media_type': media.type.anilistValue,
        'title': media.title,
        'cover_url': media.coverUrl,
        'total_units': total,
        'status': status.wire,
        'progress': safeProgress,
        'score': score,
        'notes': notes,
        'started_at': now.toIso8601String(),
        'completed_at':
            status == ListStatus.completed ? now.toIso8601String() : null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
    } else {
      row = {
        ...existing,
        'title': media.title,
        'cover_url': media.coverUrl.isEmpty ? existing['cover_url'] : media.coverUrl,
        'total_units': total,
        'status': status.wire,
        'progress': safeProgress,
        'score': score ?? existing['score'],
        'notes': notes ?? existing['notes'],
        'completed_at': status == ListStatus.completed
            ? (existing['completed_at'] ?? now.toIso8601String())
            : null,
        'updated_at': now.toIso8601String(),
      };
    }

    final inserted = await _db
        .from(table)
        .upsert(row, onConflict: 'user_id,media_id,media_type')
        .select()
        .single();
    return _fromRow(inserted);
  }

  @override
  Future<MediaEntry> setStatus(int mediaId, ListStatus status) {
    return _patch(mediaId, {
      'status': status.wire,
      if (status == ListStatus.completed) 'completed_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<MediaEntry> setProgress(int mediaId, int progress) async {
    return _patch(mediaId, {'progress': progress});
  }

  @override
  Future<MediaEntry> incrementProgress(int mediaId) async {
    final current = await _find(mediaId);
    final total = current.totalUnits;
    final next = total == null ? current.progress + 1 : (current.progress + 1).clamp(0, total);
    return _patch(mediaId, {
      'progress': next,
      'status': total != null && next >= total
          ? ListStatus.completed.wire
          : ListStatus.watching.wire,
      if (total != null && next >= total)
        'completed_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<MediaEntry> setScore(int mediaId, int? score) {
    return _patch(mediaId, {'score': score});
  }

  @override
  Future<void> remove(int mediaId) async {
    final userId = _userId;
    await _db.from(table).delete().eq('user_id', userId).eq('media_id', mediaId);
  }

  @override
  Future<void> clear() async {
    final userId = _userId;
    await _db.from(table).delete().eq('user_id', userId);
  }

  @override
  Future<MediaEntry?> entryFor(int mediaId) async {
    try {
      return await _find(mediaId);
    } on AppException {
      return null;
    }
  }

  Future<MediaEntry> _find(int mediaId) async {
    final userId = _userId;
    final row = await _db
        .from(table)
        .select()
        .eq('user_id', userId)
        .eq('media_id', mediaId)
        .maybeSingle();
    if (row == null) {
      throw AppException(ErrorKind.notFound, 'Title $mediaId is not tracked');
    }
    return _fromRow(row);
  }

  Future<MediaEntry> _patch(int mediaId, Map<String, dynamic> changes) async {
    final userId = _userId;
    final row = await _db
        .from(table)
        .update({...changes, 'updated_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .eq('media_id', mediaId)
        .select()
        .maybeSingle();
    if (row == null) {
      throw AppException(ErrorKind.notFound, 'Title $mediaId is not tracked');
    }
    return _fromRow(row);
  }

  static MediaEntry _fromRow(Map<String, dynamic> row) {
    return MediaEntry(
      mediaId: (row['media_id'] as num).toInt(),
      type: MediaType.fromWire(row['media_type'] as String?),
      title: (row['title'] as String?) ?? 'Untitled',
      coverUrl: row['cover_url'] as String?,
      totalUnits: (row['total_units'] as num?)?.toInt(),
      status: ListStatus.fromWire(row['status'] as String?),
      progress: (row['progress'] as num?)?.toInt() ?? 0,
      score: (row['score'] as num?)?.toInt(),
      notes: row['notes'] as String?,
      startedAt: DateTime.tryParse(row['started_at'] as String? ?? ''),
      completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
