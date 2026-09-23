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
    this.collectionTime,
    this.className,
    this.isArchived = false,
  });

  /// String ID from D1 integer.
  final String id;
  final String title;
  final String? description;
  final String date;
  final String endDate;
  final String? location;
  final String? category;
  final String? collectionTime;
  final String? className;
  final bool isArchived;

  factory JtkCalendar.fromJson(Map<String, dynamic> json) {
    return JtkCalendar(
      id: (json['id'] as int).toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String,
      endDate: json['end_date'] as String? ?? '',
      location: json['location'] as String?,
      category: json['category'] as String?,
      collectionTime: json['collection_time'] as String?,
      className: json['class_name'] as String?,
      isArchived: (json['is_archived'] as int? ?? 0) == 1,
    );
  }

  /// Safely decode a list of [JtkCalendar] from raw JSON array.
  static List<JtkCalendar> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(JtkCalendar.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() => {
    'id': int.tryParse(id) ?? id,
    'title': title,
    if (description != null) 'description': description,
    'date': date,
    'end_date': endDate,
    if (location != null) 'location': location,
    if (category != null) 'category': category,
    if (collectionTime != null) 'collection_time': collectionTime,
    if (className != null) 'class_name': className,
    'is_archived': isArchived ? 1 : 0,
  };
}
