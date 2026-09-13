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
