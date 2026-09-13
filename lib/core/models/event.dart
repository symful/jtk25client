/// Event models — mirrors server schema v2 exactly.
library;

/// A campus event for JTK25 students.
class JtkEvent {
  const JtkEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    required this.endDate,
    this.location,
    this.category,
  });

  final String id;
  final String title;
  final String? description;
  final String date;
  final String endDate;
  final String? location;
  final String? category;

  factory JtkEvent.fromJson(Map<String, dynamic> json) {
    return JtkEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String,
      endDate: json['endDate'] as String,
      location: json['location'] as String?,
      category: json['category'] as String?,
    );
  }

  /// Safely decode a list of [JtkEvent] from raw JSON.
  ///
  /// Accepts a raw JSON array or a `{"data": [...]}` envelope.
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<JtkEvent> listFromJson(dynamic raw) {
    final list = _unwrapList(raw);
    return list.map((e) => JtkEvent.fromJson(e)).toList();
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
    if (description != null) 'description': description,
    'date': date,
    'endDate': endDate,
    if (location != null) 'location': location,
    if (category != null) 'category': category,
  };
}
