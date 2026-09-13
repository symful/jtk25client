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
