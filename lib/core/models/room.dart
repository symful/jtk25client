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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (type != null) 'type': type!.label,
  };
}
