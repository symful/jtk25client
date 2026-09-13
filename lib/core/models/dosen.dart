/// Dosen (lecturer) models — mirrors server schema v2 exactly.
library;

/// A lecturer in the JTK department.
class Dosen {
  const Dosen({required this.code, required this.name, this.email});

  final String code;
  final String name;
  final String? email;

  factory Dosen.fromJson(Map<String, dynamic> json) {
    return Dosen(
      code: json['code'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
    );
  }

  /// Safely decode a list of [Dosen] from raw JSON.
  ///
  /// Accepts a raw JSON array or a `{"data": [...]}` envelope.
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<Dosen> listFromJson(dynamic raw) {
    final list = _unwrapList(raw);
    return list.map((e) => Dosen.fromJson(e)).toList();
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
    'code': code,
    'name': name,
    if (email != null) 'email': email,
  };
}
