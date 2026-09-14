/// Lecturers data layer — compute "Mengajarkan" sessions for each dosen.
///
/// Scans all class schedules to find sessions where the dosen's code
/// appears in the comma-separated lecturer_code field.
library;

import '../../../core/models/schedule.dart';

/// A session taught by a specific dosen, tagged with the class it belongs to.
class DosenSession {
  const DosenSession({
    required this.classCode,
    required this.day,
    required this.session,
  });

  /// The class code this session belongs to (e.g. "D3-2A").
  final String classCode;

  /// Day of the week.
  final Day day;

  /// The raw session data.
  final Session session;
}

/// Compute all sessions taught by [lecturerCode] across all classes.
///
/// [lecturerCode] is a single code like "MV". The function matches it
/// against comma-separated lecturer_code fields in each session.
List<DosenSession> computeDosenSessions(
  String lecturerCode,
  List<ScheduleClass> classes,
) {
  final results = <DosenSession>[];
  final target = lecturerCode.trim();

  for (final cls in classes) {
    for (final daySchedule in cls.schedule) {
      for (final session in daySchedule.sessions) {
        final codes = session.lecturerCodes;
        if (codes.contains(target)) {
          results.add(
            DosenSession(
              classCode: cls.className,
              day: daySchedule.day,
              session: session,
            ),
          );
        }
      }
    }
  }

  // Sort by day order, then by start time.
  results.sort((a, b) {
    final dayCmp = a.day.index.compareTo(b.day.index);
    if (dayCmp != 0) return dayCmp;
    return a.session.time.compareTo(b.session.time);
  });

  return results;
}
