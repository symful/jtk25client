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

  /// Safely decode a list of [Dosen] from raw JSON array.
  static List<Dosen> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(Dosen.fromJson).toList();
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    if (email != null) 'email': email,
  };
}
