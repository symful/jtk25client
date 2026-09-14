/// Calendar models — handles D1 database rows with integer IDs and snake_case fields.
library;

/// A campus event for JTK25 students.
class JtkCalendar {
  const JtkCalendar({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.endDate,
    this.location,
    this.category,
  });

  /// String ID for internal use (parsed from D1 int or legacy string).
  final String id;
  final String title;
  final String? description;
  final String date;
  final String endDate;
  final String? location;
  final String? category;

  /// Parse id from D1 (int) or legacy format (String).
  static String _parseId(dynamic value) {
    if (value is int) return value.toString();
    if (value is String) return value;
    return '';
  }

  factory JtkCalendar.fromJson(Map<String, dynamic> json) {
    return JtkCalendar(
      id: _parseId(json['id']),
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String,
      endDate: json['end_date'] as String? ?? json['endDate'] as String? ?? '',
      location: json['location'] as String?,
      category: json['category'] as String?,
    );
  }

  /// Safely decode a list of [JtkCalendar] from raw JSON.
  ///
  /// Accepts a raw JSON array or a `{"data": [...]}` envelope.
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<JtkCalendar> listFromJson(dynamic raw) {
    final list = _unwrapList(raw);
    return list.map((e) => JtkCalendar.fromJson(e)).toList();
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
    if (description != null) 'description': description,
    'date': date,
    'end_date': endDate,
    if (location != null) 'location': location,
    if (category != null) 'category': category,
  };
}
