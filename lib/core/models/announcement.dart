/// Announcement models — handles D1 database rows with integer IDs and snake_case fields.
library;

/// An announcement for JTK25 students.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.pinned = false,
    required this.createdAt,
    this.expiresAt,
  });

  /// String ID from D1 integer.
  final String id;
  final String title;
  final String body;
  final bool pinned;
  final String createdAt;
  final String? expiresAt;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as int).toString(),
      title: json['title'] as String,
      body: json['body'] as String,
      pinned: (json['pinned'] as int? ?? 0) != 0,
      createdAt: json['created_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String?,
    );
  }

  /// Safely decode a list of [Announcement] from raw JSON array.
  static List<Announcement> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Announcement.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() => {
    'id': int.tryParse(id) ?? id,
    'title': title,
    'body': body,
    'pinned': pinned ? 1 : 0,
    'created_at': createdAt,
    if (expiresAt != null) 'expires_at': expiresAt,
  };

  /// Whether this announcement has expired at [now].
  bool isExpired(DateTime now) {
    if (expiresAt == null) return false;
    final exp = DateTime.tryParse(expiresAt!);
    if (exp == null) return false;
    return now.isAfter(exp);
  }
}
