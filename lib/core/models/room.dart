/// Room models — mirrors server schema v2 exactly.
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
  const Room({required this.id, required this.name, this.type});

  final String id;
  final String name;
  final RoomType? type;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
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
    'id': id,
    'name': name,
    if (type != null) 'type': type!.label,
  };
}
