/// Announcement models — mirrors server schema v2 exactly.
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

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final String createdAt;
  final String? expiresAt;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      pinned: json['pinned'] as bool? ?? false,
      createdAt: json['createdAt'] as String,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  /// Safely decode a list of [Announcement] from raw JSON.
  ///
  /// Accepts a raw JSON array or a `{"data": [...]}` envelope.
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<Announcement> listFromJson(dynamic raw) {
    final list = _unwrapList(raw);
    return list.map((e) => Announcement.fromJson(e)).toList();
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
    'title': title,
    'body': body,
    'pinned': pinned,
    'createdAt': createdAt,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };

  /// Whether this announcement has expired at [now].
  bool isExpired(DateTime now) {
    if (expiresAt == null) return false;
    final exp = DateTime.tryParse(expiresAt!);
    if (exp == null) return false;
    return now.isAfter(exp);
  }
}
