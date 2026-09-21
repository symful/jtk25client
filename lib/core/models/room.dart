/// Room models — handles D1 database rows with integer IDs.
library;

/// Room type.
enum RoomType {
  kelas,
  lab;

  String get label => switch (this) {
    RoomType.kelas => 'kelas',
    RoomType.lab => 'lab',
  };

  static RoomType? fromJson(String value) {
    for (final t in values) {
      if (t.label == value) return t;
    }
    return null;
  }
}

/// A room in the JTK building.
class Room {
  const Room({required this.id, required this.name, this.type, String? extId})
    : extId = extId ?? id;

  /// Database primary key (D1 integer).
  final String id;

  /// Room identifier matching schedule data (e.g. "D108-Kelas").
  /// Falls back to [id] for legacy data without ext_id.
  final String extId;

  final String name;
  final RoomType? type;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: (json['id'] as int).toString(),
      extId: json['ext_id'] as String? ?? (json['id'] as int).toString(),
      name: json['name'] as String,
      type: json['type'] != null
          ? RoomType.fromJson(json['type'] as String)
          : null,
    );
  }

  /// Safely decode a list of [Room] from raw JSON.
  ///
  /// Accepts a raw JSON array or a `{"data": [...]}` envelope.
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<Room> listFromJson(dynamic raw) {
    final list = _unwrapList(raw);
    return list.map((e) => Room.fromJson(e)).toList();
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
    'id': int.tryParse(id) ?? id,
    'ext_id': extId,
    'name': name,
    if (type != null) 'type': type!.label,
  };
}
