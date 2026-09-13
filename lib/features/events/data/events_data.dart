/// Events feature data layer — grouping helpers.
///
/// Thin helpers on top of T8's events provider. No additional persistence needed.
library;

import 'package:jtk25_client/core/models/event.dart';

/// Two groups for events: upcoming vs completed.
class EventGroup {
  const EventGroup({required this.label, required this.items});

  final String label;
  final List<JtkEvent> items;
}

/// Split events into "Akan Datang" (upcoming) and "Selesai" (completed)
/// based on [endDate] vs [now].
List<EventGroup> groupEvents(List<JtkEvent> events, DateTime now) {
  final upcoming = <JtkEvent>[];
  final completed = <JtkEvent>[];

  for (final e in events) {
    final end = DateTime.tryParse(e.endDate);
    if (end != null && now.isAfter(end)) {
      completed.add(e);
    } else {
      upcoming.add(e);
    }
  }

  // Sort upcoming ascending (nearest first), completed descending (most recent first).
  upcoming.sort((a, b) {
    final da = DateTime.tryParse(a.date) ?? DateTime(0);
    final db = DateTime.tryParse(b.date) ?? DateTime(0);
    return da.compareTo(db);
  });
  completed.sort((a, b) {
    final da = DateTime.tryParse(a.endDate) ?? DateTime(0);
    final db = DateTime.tryParse(b.endDate) ?? DateTime(0);
    return db.compareTo(da);
  });

  return [
    if (upcoming.isNotEmpty) EventGroup(label: 'Akan Datang', items: upcoming),
    if (completed.isNotEmpty) EventGroup(label: 'Selesai', items: completed),
  ];
}

/// Whether a [location] string looks like a URL or geo URI.
bool isLocationUrl(String? location) {
  if (location == null) return false;
  final l = location.toLowerCase();
  return l.startsWith('http://') ||
      l.startsWith('https://') ||
      l.startsWith('geo:');
}
