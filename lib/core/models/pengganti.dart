/// Pengganti (schedule override) models — mirrors server schema v2 exactly.
library;

import 'schedule.dart';

/// Kind of pengganti entry.
enum PenggantiKind {
  replace,
  add,
  info;

  String get label => switch (this) {
    PenggantiKind.replace => 'replace',
    PenggantiKind.add => 'add',
    PenggantiKind.info => 'info',
  };

  static PenggantiKind fromJson(String value) {
    for (final k in values) {
      if (k.label == value) return k;
    }
    return PenggantiKind.replace;
  }
}

/// A single pengganti entry: a dated override or addition.
class PenggantiEntry {
  const PenggantiEntry({
    required this.id,
    required this.classCode,
    required this.date,
    required this.kind,
    this.note,
    this.sessions = const [],
  });

  final String id;
  final String classCode;

  /// Date in YYYY-MM-DD format.
  final String date;
  final PenggantiKind kind;
  final String? note;
  final List<Session> sessions;

  factory PenggantiEntry.fromJson(Map<String, dynamic> json) {
    return PenggantiEntry(
      id: json['id'] as String,
      classCode: json['class_code'] as String,
      date: json['date'] as String,
      kind: PenggantiKind.fromJson(json['kind'] as String),
      note: json['note'] as String?,
      sessions: Session.listFromJson(json['sessions']),
    );
  }

  /// Safely decode a list of [PenggantiEntry] from raw JSON.
  ///
  /// Accepts a raw JSON array or a `{"data": [...]}` envelope.
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<PenggantiEntry> listFromJson(dynamic raw) {
    final list = _unwrapList(raw);
    return list.map((e) => PenggantiEntry.fromJson(e)).toList();
  }

  static List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    final List<dynamic>? items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map<String, dynamic>) {
      final inner = raw['data'];
      items = inner is List ? inner : null;
    } else {
      items = null;
    }
    if (items == null) return const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'class_code': classCode,
    'date': date,
    'kind': kind.label,
    if (note != null) 'note': note,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };
}

/// Resolve pengganti entries for a specific class and date.
///
/// Rules:
/// - `replace`: remove matching default sessions, insert pengganti sessions
/// - `add`: append pengganti sessions to existing sessions
/// - `info`: banner only, no session changes
/// - When two pengganti entries target the same slot with replace kind,
///   the last one wins deterministically (sorted by id).
List<Session> resolvePengganti({
  required List<Session> defaultSessions,
  required List<PenggantiEntry> entries,
}) {
  if (entries.isEmpty) return defaultSessions;

  // Sort by id for deterministic ordering.
  final sorted = List<PenggantiEntry>.from(entries)
    ..sort((a, b) => a.id.compareTo(b.id));

  var result = List<Session>.from(defaultSessions);

  for (final entry in sorted) {
    switch (entry.kind) {
      case PenggantiKind.replace:
        // Replace sessions whose time appears in the pengganti sessions.
        final replaceTimes = entry.sessions.map((s) => s.time).toSet();
        result = [
          ...result.where((s) => !replaceTimes.contains(s.time)),
          ...entry.sessions,
        ];
      case PenggantiKind.add:
        result = [...result, ...entry.sessions];
      case PenggantiKind.info:
        // Info entries don't modify sessions.
        break;
    }
  }

  return result;
}
