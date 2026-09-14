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

  /// String ID for internal use (parsed from D1 int or legacy string).
  final String id;
  final String title;
  final String body;
  final bool pinned;
  final String createdAt;
  final String? expiresAt;

  /// Parse id from D1 (int) or legacy format (String).
  static String _parseId(dynamic value) {
    if (value is int) return value.toString();
    if (value is String) return value;
    return '';
  }

  /// Parse pinned from D1 (int 0/1) or legacy format (bool).
  static bool _parsePinned(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    return false;
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: _parseId(json['id']),
      title: json['title'] as String,
      body: json['body'] as String,
      pinned: _parsePinned(json['pinned']),
      createdAt:
          json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? json['expiresAt'] as String?,
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
