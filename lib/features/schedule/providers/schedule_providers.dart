/// Schedule feature providers — view mode, merged sessions, resolved schedule.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/models/pengganti.dart';
import '../../../core/models/schedule.dart';
import '../../../core/utils/time_slot.dart';
import '../../settings/data/settings_data.dart';

// ---------------------------------------------------------------------------
// View mode
// ---------------------------------------------------------------------------

/// Whether the schedule view shows today or the full week.
enum ScheduleViewMode { today, week }

/// Notifier for the schedule view mode toggle.
class _ViewModeNotifier extends Notifier<ScheduleViewMode> {
  @override
  ScheduleViewMode build() => ScheduleViewMode.today;

  void setMode(ScheduleViewMode mode) => state = mode;
}

/// Current schedule view mode (today / week).
final scheduleViewModeProvider =
    NotifierProvider<_ViewModeNotifier, ScheduleViewMode>(
      _ViewModeNotifier.new,
    );

// ---------------------------------------------------------------------------
// Selected class (Hive-persisted)
// ---------------------------------------------------------------------------

/// Notifier for the currently selected class code.
///
/// Persisted in Hive so the user's choice survives app restarts.
class _SelectedClassNotifier extends Notifier<String> {
  @override
  String build() {
    final box = Hive.box(kSettingsBoxName);
    final saved = box.get(SettingsKeys.selectedClass) as String?;
    if (saved != null && kAllClassCodes.contains(saved)) return saved;
    return kAllClassCodes.first;
  }

  /// Select a different class and persist the choice.
  void select(String classCode) {
    if (!kAllClassCodes.contains(classCode)) return;
    state = classCode;
    Hive.box(kSettingsBoxName).put(SettingsKeys.selectedClass, classCode);
  }
}

/// The currently selected class code (persisted in Hive).
final selectedClassProvider = NotifierProvider<_SelectedClassNotifier, String>(
  _SelectedClassNotifier.new,
);

// ---------------------------------------------------------------------------
// Merged session model
// ---------------------------------------------------------------------------

/// A display-ready block: one or more consecutive same-course sessions merged.
class MergedSession {
  const MergedSession({
    required this.courseCode,
    required this.courseName,
    required this.type,
    required this.lecturerCode,
    required this.lecturer,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.originalSessions,
  });

  final String courseCode;
  final String courseName;
  final CourseType type;
  final String lecturerCode;
  final String lecturer;
  final String room;

  /// Display time string, e.g. "07.00–12.20".
  final String startTime;
  final String endTime;

  /// The raw sessions that were merged into this block.
  final List<Session> originalSessions;

  /// Display time range in Indonesian format.
  String get timeRange => '$startTime–$endTime';

  /// Full display label for type: "Teori" or "Praktik".
  String get typeLabel => type == CourseType.te ? 'Teori' : 'Praktik';
}

/// Merge consecutive sessions with the same [courseCode] into single blocks.
///
/// Sessions must be in chronological order. Two sessions merge if they have
/// the same course code, regardless of gaps (breaks, lunch, etc.).
List<MergedSession> mergeSessions(List<Session> sessions) {
  if (sessions.isEmpty) return [];

  final result = <MergedSession>[];
  var current = sessions.first;
  var currentStart = _extractStartTime(current.time);
  var currentEnd = _extractEndTime(current.time);
  var merged = <Session>[current];

  for (var i = 1; i < sessions.length; i++) {
    final session = sessions[i];
    if (session.courseCode == current.courseCode) {
      // Extend the merge block.
      currentEnd = _extractEndTime(session.time);
      merged.add(session);
    } else {
      // Flush current block.
      result.add(
        MergedSession(
          courseCode: current.courseCode,
          courseName: current.courseName,
          type: current.type,
          lecturerCode: current.lecturerCode,
          lecturer: current.lecturer,
          room: current.room,
          startTime: currentStart,
          endTime: currentEnd,
          originalSessions: List.unmodifiable(merged),
        ),
      );
      current = session;
      currentStart = _extractStartTime(session.time);
      currentEnd = _extractEndTime(session.time);
      merged = [session];
    }
  }

  // Flush the last block.
  result.add(
    MergedSession(
      courseCode: current.courseCode,
      courseName: current.courseName,
      type: current.type,
      lecturerCode: current.lecturerCode,
      lecturer: current.lecturer,
      room: current.room,
      startTime: currentStart,
      endTime: currentEnd,
      originalSessions: List.unmodifiable(merged),
    ),
  );

  return result;
}

/// Extract the start time portion from a dot-time range string.
String _extractStartTime(String time) => time.split('-').first.trim();

/// Extract the end time portion from a dot-time range string.
String _extractEndTime(String time) => time.split('-').last.trim();

// ---------------------------------------------------------------------------
// Pengganti note helper
// ---------------------------------------------------------------------------

/// A pengganti banner descriptor for a given class + date.
class PenggantiNote {
  const PenggantiNote({required this.kind, required this.entries});

  final PenggantiKind kind;
  final List<PenggantiEntry> entries;

  /// Combined note text from all matching entries.
  String get noteText =>
      entries.map((e) => e.note ?? '').where((n) => n.isNotEmpty).join('\n');

  bool get hasNote => noteText.isNotEmpty;
}

/// Find pengganti entries for a specific class and date.
PenggantiNote? findPengganti({
  required String classCode,
  required String date,
  required List<PenggantiEntry> entries,
}) {
  final matching = entries
      .where((e) => e.classCode == classCode && e.date == date)
      .toList();
  if (matching.isEmpty) return null;

  // Determine the dominant kind (replace > add > info).
  final kind = matching.any((e) => e.kind == PenggantiKind.replace)
      ? PenggantiKind.replace
      : matching.any((e) => e.kind == PenggantiKind.add)
      ? PenggantiKind.add
      : PenggantiKind.info;

  return PenggantiNote(kind: kind, entries: matching);
}

// ---------------------------------------------------------------------------
// Resolved schedule data for a specific class + date
// ---------------------------------------------------------------------------

/// Computed schedule for a single day, with pengganti applied and sessions merged.
class DayScheduleData {
  const DayScheduleData({
    required this.day,
    required this.mergedSessions,
    required this.penggantiNote,
  });

  final Day day;
  final List<MergedSession> mergedSessions;
  final PenggantiNote? penggantiNote;

  bool get isEmpty => mergedSessions.isEmpty;
}

/// Compute the resolved day schedule for [classCode] on [date].
///
/// Applies pengganti overrides (replace / add / info), then merges
/// consecutive same-course sessions into display blocks.
DayScheduleData resolveDaySchedule({
  required String classCode,
  required DateTime date,
  required List<DaySchedule> classSchedule,
  required List<PenggantiEntry> penggantiEntries,
}) {
  // Determine which day of week this date falls on.
  final wibNow = date.toUtc().add(const Duration(hours: 7));
  final targetWeekday = wibNow.weekday;

  // Find the matching Day enum.
  final day = Day.values.firstWhere(
    (d) => d.index + 1 == targetWeekday,
    orElse: () => Day.senin,
  );

  // Find the raw sessions for this day.
  final dayEntry = classSchedule.where((d) => d.day == day).firstOrNull;
  final defaultSessions = dayEntry?.sessions ?? [];

  // Find pengganti entries for this class + date (YYYY-MM-DD).
  final dateStr =
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final matchingPengganti = penggantiEntries
      .where((e) => e.classCode == classCode && e.date == dateStr)
      .toList();

  // Apply pengganti overrides.
  final resolved = resolvePengganti(
    defaultSessions: defaultSessions,
    entries: matchingPengganti,
  );

  // Merge consecutive same-course sessions.
  final merged = mergeSessions(resolved);

  // Compute pengganti note for banner.
  final penggantiNote = findPengganti(
    classCode: classCode,
    date: dateStr,
    entries: penggantiEntries,
  );

  return DayScheduleData(
    day: day,
    mergedSessions: merged,
    penggantiNote: penggantiNote,
  );
}

/// Check if a merged session block is currently active (contains the current WIB time).
bool isSessionActive(MergedSession session, DateTime now) {
  final slot = TimeSlot.parse('${session.startTime}-${session.endTime}');
  if (slot == null) return false;
  return slot.containsMinutes(wibMinutes(now));
}
