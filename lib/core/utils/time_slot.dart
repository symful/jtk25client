/// Dot-time parsing and slot utilities for JTK25 schedules.
///
/// All time comparisons use FIXED UTC+7 (WIB / Asia/Jakarta).
/// Never uses device-local timezone for slot math.
library;

import '../models/schedule.dart';

/// A time-of-day in WIB (UTC+7), represented as minutes since midnight.
class WibTime {
  const WibTime(this.hour, this.minute)
    : assert(hour >= 0 && hour <= 23),
      assert(minute >= 0 && minute <= 59);

  final int hour;
  final int minute;

  /// Total minutes since midnight in WIB.
  int get totalMinutes => hour * 60 + minute;

  /// Parse "HH.MM" dot-time component → [WibTime].
  static WibTime? parse(String dotComponent) {
    final parts = dotComponent.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return WibTime(h, m);
  }

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is WibTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => totalMinutes;
}

/// A time-of-day range in WIB (UTC+7).
///
/// Supports both single-jam slots ("07.00-07.50") and multi-jam spans
/// ("07.00-12.20", "11.30-15.20").
class TimeSlot {
  const TimeSlot(this.start, this.end);

  final WibTime start;
  final WibTime end;

  /// Duration in minutes.
  int get durationMinutes => end.totalMinutes - start.totalMinutes;

  /// Whether [wibMinutes] (minutes since midnight) falls within this slot.
  /// Inclusive of start, exclusive of end.
  bool containsMinutes(int wibMinutes) =>
      wibMinutes >= start.totalMinutes && wibMinutes < end.totalMinutes;

  /// Parse a dot-time range string like "07.00-07.50" or "07.00-12.20".
  static TimeSlot? parse(String dotTimeRange) {
    final parts = dotTimeRange.split('-');
    if (parts.length != 2) return null;
    final start = WibTime.parse(parts[0].trim());
    final end = WibTime.parse(parts[1].trim());
    if (start == null || end == null) return null;
    if (end.totalMinutes <= start.totalMinutes) return null;
    return TimeSlot(start, end);
  }

  @override
  String toString() => '$start-$end';

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.start == start && other.end == end;

  @override
  int get hashCode => start.totalMinutes * 1000 + end.totalMinutes;
}

/// Convert a [Day] enum to the next [DateTime] (in WIB) matching that day.
///
/// Given a reference [DateTime], returns the most recent or same occurrence
/// of [day] at midnight WIB (00:00 UTC+7). If today is [day], returns today.
/// Otherwise walks forward (max 7 days) to find the next occurrence.
DateTime dayToDate(Day day, {DateTime? reference}) {
  final now = reference ?? DateTime.now();
  final wibNow = _toWib(now);

  // Map Day enum to DateTime.weekday (1=Mon..7=Sun).
  final targetWeekday = switch (day) {
    Day.senin => DateTime.monday,
    Day.selasa => DateTime.tuesday,
    Day.rabu => DateTime.wednesday,
    Day.kamis => DateTime.thursday,
    Day.jumat => DateTime.friday,
    Day.sabtu => DateTime.saturday,
    Day.minggu => DateTime.sunday,
  };

  var candidate = DateTime(wibNow.year, wibNow.month, wibNow.day);
  // Walk forward until we match the target weekday.
  for (var i = 0; i < 7; i++) {
    if (candidate.weekday == targetWeekday) break;
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

/// Return the current WIB time as minutes since midnight.
int wibMinutes(DateTime utcOrLocal) {
  final wib = _toWib(utcOrLocal);
  return wib.hour * 60 + wib.minute;
}

/// Find the currently active session from [sessions] at WIB time [now].
///
/// Returns the first session whose dot-time range contains the current
/// WIB time. Returns null during breaks, before/after sessions, or on
/// empty days. No infinite loops.
Session? currentSlot(DateTime now, List<Session> sessions) {
  if (sessions.isEmpty) return null;
  final minutes = wibMinutes(now);
  for (final session in sessions) {
    final slot = TimeSlot.parse(session.time);
    if (slot != null && slot.containsMinutes(minutes)) {
      return session;
    }
  }
  return null;
}

/// Find the start time of the next session after [now].
///
/// Returns the [WibTime] of the next session that hasn't started yet,
/// or null if no more sessions today.
WibTime? nextSlotStart(DateTime now, List<Session> sessions) {
  if (sessions.isEmpty) return null;
  final minutes = wibMinutes(now);
  for (final session in sessions) {
    final slot = TimeSlot.parse(session.time);
    if (slot != null && slot.start.totalMinutes > minutes) {
      return slot.start;
    }
  }
  return null;
}

/// Check if a given WIB time falls within a known break period.
///
/// Breaks: 09.30-09.50, 12.20-13.00, 15.20-15.40.
bool isBreak(int wibMinutes) {
  const breaks = [
    (start: 9 * 60 + 30, end: 9 * 60 + 50), // 09.30-09.50
    (start: 12 * 60 + 20, end: 13 * 60), // 12.20-13.00
    (start: 15 * 60 + 20, end: 15 * 60 + 40), // 15.20-15.40
  ];
  for (final b in breaks) {
    if (wibMinutes >= b.start && wibMinutes < b.end) return true;
  }
  return false;
}

/// Convert any DateTime to WIB (UTC+7).
DateTime _toWib(DateTime dt) {
  final utc = dt.isUtc ? dt : dt.toUtc();
  return utc.add(const Duration(hours: 7));
}
