/// Calendar feature data layer — grouping helpers.
///
/// Thin helpers on top of T8's calendar provider. No additional persistence needed.
library;

import 'package:intl/intl.dart';
import 'package:jtk25_client/core/models/calendar.dart';
import 'package:jtk25_client/core/models/pengganti.dart';

// ---------------------------------------------------------------------------
// Legacy two-group helper (kept for backward compatibility)
// ---------------------------------------------------------------------------

/// Two groups for events: upcoming vs completed.
class CalendarGroup {
  const CalendarGroup({required this.label, required this.items});

  final String label;
  final List<JtkCalendar> items;
}

/// Split events into "Akan Datang" (upcoming) and "Selesai" (completed)
/// based on [endDate] vs [now].
List<CalendarGroup> groupEvents(List<JtkCalendar> events, DateTime now) {
  final upcoming = <JtkCalendar>[];
  final completed = <JtkCalendar>[];

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
    if (upcoming.isNotEmpty)
      CalendarGroup(label: 'Akan Datang', items: upcoming),
    if (completed.isNotEmpty) CalendarGroup(label: 'Selesai', items: completed),
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

// ---------------------------------------------------------------------------
// Unified calendar list items
// ---------------------------------------------------------------------------

/// A unified calendar list item — either an event or a pengganti entry.
sealed class CalendarListItem {
  const CalendarListItem();
}

/// Calendar event wrapper.
class CalendarEventItem extends CalendarListItem {
  const CalendarEventItem(this.event);
  final JtkCalendar event;
}

/// Pengganti entry wrapper.
class CalendarPenggantiItem extends CalendarListItem {
  const CalendarPenggantiItem(this.entry);
  final PenggantiEntry entry;
}

// ---------------------------------------------------------------------------
// Month grouping
// ---------------------------------------------------------------------------

/// A group of calendar items for a specific month.
class CalendarMonthGroup {
  const CalendarMonthGroup({
    required this.yearMonth,
    required this.label,
    required this.upcoming,
    required this.past,
  });

  /// Year-month key for comparison (e.g., DateTime(2026, 9)).
  final DateTime yearMonth;

  /// Display label (e.g., 'September 2026').
  final String label;

  /// Upcoming items in this month (sorted ascending by date).
  final List<CalendarListItem> upcoming;

  /// Past items in this month (sorted descending by date).
  final List<CalendarListItem> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;
}

/// Group all calendar items (events + pengganti) by month.
///
/// For each month, upcoming items are sorted ascending (nearest first),
/// past items sorted descending (most recent first).
/// Months with upcoming items appear before months with only past items.
List<CalendarMonthGroup> groupByMonth({
  required List<JtkCalendar> events,
  required List<PenggantiEntry> penggantiEntries,
  required String classCode,
  required DateTime wibNow,
}) {
  // Build unified items list.
  final items = <CalendarListItem>[];

  // Add events (one entry per event, regardless of multi-day).
  for (final event in events) {
    items.add(CalendarEventItem(event));
  }

  // Add pengganti filtered by class.
  for (final entry in penggantiEntries) {
    if (entry.classCode == classCode) {
      items.add(CalendarPenggantiItem(entry));
    }
  }

  // Group by year-month.
  final monthMap = <DateTime, List<CalendarListItem>>{};
  for (final item in items) {
    final date = _itemDate(item);
    if (date == null) continue;
    final ym = DateTime(date.year, date.month);
    monthMap.putIfAbsent(ym, () => []).add(item);
  }

  // Split each month into upcoming/past.
  final result = <CalendarMonthGroup>[];
  for (final entry in monthMap.entries) {
    final upcoming = <CalendarListItem>[];
    final past = <CalendarListItem>[];

    for (final item in entry.value) {
      if (_isUpcoming(item, wibNow)) {
        upcoming.add(item);
      } else {
        past.add(item);
      }
    }

    // Sort upcoming ascending by date.
    upcoming.sort(
      (a, b) =>
          (_itemDate(a) ?? DateTime(0)).compareTo(_itemDate(b) ?? DateTime(0)),
    );
    // Sort past descending by date.
    past.sort(
      (a, b) =>
          (_itemDate(b) ?? DateTime(0)).compareTo(_itemDate(a) ?? DateTime(0)),
    );

    result.add(
      CalendarMonthGroup(
        yearMonth: entry.key,
        label: DateFormat('MMMM yyyy', 'id').format(entry.key),
        upcoming: upcoming,
        past: past,
      ),
    );
  }

  // Sort groups: months with upcoming items first (ascending),
  // then months with only past items (descending).
  result.sort((a, b) {
    final aHasUpcoming = a.upcoming.isNotEmpty;
    final bHasUpcoming = b.upcoming.isNotEmpty;
    if (aHasUpcoming && !bHasUpcoming) return -1;
    if (!aHasUpcoming && bHasUpcoming) return 1;
    if (aHasUpcoming) return a.yearMonth.compareTo(b.yearMonth);
    return b.yearMonth.compareTo(a.yearMonth);
  });

  return result;
}

/// Get the primary date of a calendar list item.
DateTime? _itemDate(CalendarListItem item) {
  return switch (item) {
    CalendarEventItem(:final event) => DateTime.tryParse(event.date),
    CalendarPenggantiItem(:final entry) => DateTime.tryParse(entry.date),
  };
}

/// Whether an item's start date is on or after [wibNow].
bool _isUpcoming(CalendarListItem item, DateTime wibNow) {
  final date = _itemDate(item);
  if (date == null) return false;
  final itemDay = DateTime(date.year, date.month, date.day);
  final nowDay = DateTime(wibNow.year, wibNow.month, wibNow.day);
  return !itemDay.isBefore(nowDay);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Whether an event spans multiple days (start ≠ end date).
bool isMultiDayEvent(JtkCalendar event) {
  final start = DateTime.tryParse(event.date);
  final end = DateTime.tryParse(event.endDate);
  if (start == null || end == null) return false;
  return !(start.year == end.year &&
      start.month == end.month &&
      start.day == end.day);
}

/// Get distinct category values from a list of events, sorted alphabetically.
List<String> distinctCategories(List<JtkCalendar> events) {
  final cats = <String>{};
  for (final e in events) {
    if (e.category != null && e.category!.isNotEmpty) {
      cats.add(e.category!);
    }
  }
  return cats.toList()..sort();
}
