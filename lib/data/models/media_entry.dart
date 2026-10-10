import 'media.dart';

/// Status a user can assign to a tracked title.
///
/// "Watching/Reading" is a single status; the label depends on [MediaType].
enum ListStatus {
  watching('Watching / Reading', 'Currently'),
  planning('Planning', 'Planned'),
  completed('Completed', 'Completed'),
  paused('Paused', 'Paused'),
  dropped('Dropped', 'Dropped');

  const ListStatus(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  /// Label specialized for a media type: "Watching" vs "Reading".
  String labelFor(MediaType type) =>
      this == ListStatus.watching ? type.trackingVerb : label;

  static ListStatus fromWire(String? value) {
    if (value == null) return ListStatus.planning;
    final upper = value.toUpperCase().replaceAll(' ', '_').replaceAll('/', '_');
    return switch (upper) {
      'CURRENT' || 'WATCHING' || 'READING' => ListStatus.watching,
      'PLANNING' || 'PLAN_TO_WATCH' => ListStatus.planning,
      'COMPLETED' => ListStatus.completed,
      'PAUSED' || 'HOLD' => ListStatus.paused,
      'DROPPED' => ListStatus.dropped,
      _ => ListStatus.planning,
    };
  }

  /// Wire value used when persisting to the backend / localStorage.
  String get wire => switch (this) {
        ListStatus.watching => 'CURRENT',
        ListStatus.planning => 'PLANNING',
        ListStatus.completed => 'COMPLETED',
        ListStatus.paused => 'PAUSED',
        ListStatus.dropped => 'DROPPED',
      };
}

/// A user's tracking entry for one title.
///
/// A small subset of metadata is denormalized (title/cover/total) so the
/// "My Lists" screen can render without extra AniList calls and without
/// duplicating the whole third-party record in our storage.
class MediaEntry {
  const MediaEntry({
    required this.mediaId,
    required this.type,
    required this.title,
    required this.status,
    required this.progress,
    this.coverUrl,
    this.totalUnits,
    this.score,
    this.notes,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int mediaId;
  final MediaType type;
  final String title;
  final String? coverUrl;

  /// Episode or chapter count, when known.
  final int? totalUnits;
  final ListStatus status;
  final int progress;

  /// Score on a 0-10 scale; null when unrated.
  final int? score;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isComplete =>
      status == ListStatus.completed ||
      (totalUnits != null && progress >= totalUnits!);

  /// Progress as a 0..1 fraction, for progress bars. Returns null when the
  /// total number of units is unknown.
  double? get fraction {
    final total = totalUnits;
    if (total == null || total <= 0) return null;
    return (progress / total).clamp(0.0, 1.0);
  }

  String get unit => type.unit;

  /// Sentinel that lets [copyWith] distinguish "keep the old value" from
  /// "set this field to null" (needed to clear score / unknown totals).
  static const _Unset _unset = _Unset();

  MediaEntry copyWith({
    int? mediaId,
    MediaType? type,
    String? title,
    String? coverUrl,
    Object? totalUnits = _unset,
    ListStatus? status,
    int? progress,
    Object? score = _unset,
    String? notes,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaEntry(
      mediaId: mediaId ?? this.mediaId,
      type: type ?? this.type,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      totalUnits:
          totalUnits == _unset ? this.totalUnits : totalUnits as int?,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      score: score == _unset ? this.score : score as int?,
      notes: notes ?? this.notes,
      startedAt: startedAt == _unset
          ? this.startedAt
          : startedAt as DateTime?,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'media_id': mediaId,
        'media_type': type.anilistValue,
        'title': title,
        'cover_url': coverUrl,
        'total_units': totalUnits,
        'status': status.wire,
        'progress': progress,
        'score': score,
        'notes': notes,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static MediaEntry fromJson(Map<String, dynamic> json) {
    final type = MediaType.fromWire(json['media_type'] as String?);
    return MediaEntry(
      mediaId: (json['media_id'] as num).toInt(),
      type: type,
      title: json['title'] as String? ?? 'Unknown',
      coverUrl: json['cover_url'] as String?,
      totalUnits: (json['total_units'] as num?)?.toInt(),
      status: ListStatus.fromWire(json['status'] as String?),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// Const sentinel type used by [MediaEntry.copyWith] default values.
final class _Unset {
  const _Unset();
}
