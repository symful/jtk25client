/// Rooms data layer — pure occupancy-matrix functions.
///
/// Builds a per-room × day × slot matrix from all class schedules.
/// All functions are pure (no side effects) for easy testing.
library;

import '../../../core/models/pengganti.dart';
import '../../../core/models/room.dart';
import '../../../core/models/schedule.dart';
import '../../../core/utils/time_slot.dart';

// ---------------------------------------------------------------------------
// Canonical time slots — 50-min teaching blocks, excluding breaks
// ---------------------------------------------------------------------------

/// Standard 50-minute teaching slots (WIB).
///
/// These are the grid rows for the availability matrix.
const List<String> kCanonicalSlots = [
  '07.00-07.50',
  '07.50-08.40',
  '08.40-09.30',
  '09.50-10.40',
  '10.40-11.30',
  '11.30-12.20',
  '13.00-13.50',
  '13.50-14.40',
  '14.40-15.20',
  '15.40-16.30',
];

/// Workdays for the matrix grid (Senin–Jumat).
const List<Day> kWorkdays = [
  Day.senin,
  Day.selasa,
  Day.rabu,
  Day.kamis,
  Day.jumat,
];

// ---------------------------------------------------------------------------
// Occupancy entry
// ---------------------------------------------------------------------------

/// A single occupancy entry: which class/session claims a cell in the matrix.
class SessionOccupancy {
  const SessionOccupancy({
    required this.classCode,
    required this.courseCode,
    required this.courseName,
    required this.courseType,
    required this.lecturer,
    required this.sessionTime,
  });

  /// The class that has this session (e.g. "D3-2A").
  final String classCode;

  /// Course code (e.g. "25IF2116").
  final String courseCode;

  /// Course name.
  final String courseName;

  /// TE or PR.
  final CourseType courseType;

  /// Lecturer name(s).
  final String lecturer;

  /// Raw session time range (e.g. "07.00-12.20").
  final String sessionTime;

  /// Display label for course type.
  String get typeLabel => courseType == CourseType.te ? 'Teori' : 'Praktik';
}

/// Matrix type: roomId → day → slotIndex → occupancies.
///
/// Multiple occupancies at the same cell indicate an OVERLAP.
typedef OccupancyMatrix =
    Map<String, Map<Day, Map<int, List<SessionOccupancy>>>>;

// ---------------------------------------------------------------------------
// Matrix builders
// ---------------------------------------------------------------------------

/// Build the occupancy matrix from all class schedules.
///
/// Scans every session in every class and maps it to the canonical time
/// slots it overlaps with. A session spanning "07.00-12.20" will occupy
/// all morning slots (07.00-07.50 through 11.30-12.20).
OccupancyMatrix buildOccupancyMatrix(List<ScheduleClass> classes) {
  final matrix = <String, Map<Day, Map<int, List<SessionOccupancy>>>>{};

  for (final cls in classes) {
    for (final daySchedule in cls.schedule) {
      for (final session in daySchedule.sessions) {
        final roomId = session.room;
        final day = daySchedule.day;
        final slotIndices = _findOverlappingSlots(session.time);

        matrix.putIfAbsent(roomId, () => {});
        matrix[roomId]!.putIfAbsent(day, () => {});
        for (final slotIndex in slotIndices) {
          matrix[roomId]![day]!.putIfAbsent(slotIndex, () => []);
          matrix[roomId]![day]![slotIndex]!.add(
            SessionOccupancy(
              classCode: cls.className,
              courseCode: session.courseCode,
              courseName: session.courseName,
              courseType: session.type,
              lecturer: session.lecturer,
              sessionTime: session.time,
            ),
          );
        }
      }
    }
  }

  return matrix;
}

/// Find which canonical slot indices a session time range overlaps with.
///
/// Two ranges overlap when: sessionStart < slotEnd AND sessionEnd > slotStart.
List<int> _findOverlappingSlots(String sessionTime) {
  final sessionSlot = TimeSlot.parse(sessionTime);
  if (sessionSlot == null) return [];

  final indices = <int>[];
  for (var i = 0; i < kCanonicalSlots.length; i++) {
    final gridSlot = TimeSlot.parse(kCanonicalSlots[i]);
    if (gridSlot == null) continue;
    if (sessionSlot.start.totalMinutes < gridSlot.end.totalMinutes &&
        sessionSlot.end.totalMinutes > gridSlot.start.totalMinutes) {
      indices.add(i);
    }
  }
  return indices;
}

// ---------------------------------------------------------------------------
// Matrix queries
// ---------------------------------------------------------------------------

/// Get occupancies for a specific room, day, and slot.
List<SessionOccupancy> getOccupancies(
  OccupancyMatrix matrix, {
  required String roomId,
  required Day day,
  required int slotIndex,
}) {
  return matrix[roomId]?[day]?[slotIndex] ?? const [];
}

/// Check if a specific cell is occupied (has ≥1 entries).
bool isOccupied(
  OccupancyMatrix matrix, {
  required String roomId,
  required Day day,
  required int slotIndex,
}) {
  return getOccupancies(
    matrix,
    roomId: roomId,
    day: day,
    slotIndex: slotIndex,
  ).isNotEmpty;
}

/// Check if a specific cell has an OVERLAP (2+ entries).
bool hasOverlap(
  OccupancyMatrix matrix, {
  required String roomId,
  required Day day,
  required int slotIndex,
}) {
  return getOccupancies(
        matrix,
        roomId: roomId,
        day: day,
        slotIndex: slotIndex,
      ).length >
      1;
}

// ---------------------------------------------------------------------------
// Current-time helpers (WIB-only, no device timezone)
// ---------------------------------------------------------------------------

/// Find the current canonical slot index based on WIB time.
///
/// Returns null during breaks or outside teaching hours.
int? currentSlotIndex(DateTime now) {
  final minutes = wibMinutes(now);
  for (var i = 0; i < kCanonicalSlots.length; i++) {
    final slot = TimeSlot.parse(kCanonicalSlots[i]);
    if (slot != null && slot.containsMinutes(minutes)) return i;
  }
  return null;
}

/// Get the current Day enum from WIB time.
///
/// Returns null on weekends.
Day? currentWorkDay(DateTime now) {
  final wib = now.toUtc().add(const Duration(hours: 7));
  final weekday = wib.weekday;
  if (weekday >= 1 && weekday <= 5) return Day.values[weekday - 1];
  return null;
}

/// Check if a room is available right now.
///
/// Returns true if the room has no sessions at the current WIB time
/// (or if it's a weekend/break).
bool isAvailableNow(
  OccupancyMatrix matrix, {
  required String roomId,
  required DateTime now,
}) {
  final day = currentWorkDay(now);
  final slot = currentSlotIndex(now);
  if (day == null || slot == null) return true; // Weekend or break
  return !isOccupied(matrix, roomId: roomId, day: day, slotIndex: slot);
}

/// Count how many rooms are available right now.
int countAvailableRooms(
  OccupancyMatrix matrix, {
  required List<Room> rooms,
  required DateTime now,
}) {
  return rooms
      .where((r) => isAvailableNow(matrix, roomId: r.extId, now: now))
      .length;
}

// ---------------------------------------------------------------------------
// Pengganti-aware matrix for "available now"
// ---------------------------------------------------------------------------

/// Build a date-aware occupancy matrix that applies pengganti overrides.
///
/// Takes the base weekly matrix and applies pengganti entries for the
/// given [date] (YYYY-MM-DD). This affects only the specific day of
/// the week that [date] falls on.
///
/// - `replace`: removes base sessions at the overridden times, adds new ones
/// - `add`: appends new sessions
/// - `info`: no effect on matrix
OccupancyMatrix applyPenggantiToDate(
  OccupancyMatrix baseMatrix,
  List<PenggantiEntry> penggantiEntries,
  List<ScheduleClass> classes,
  DateTime date,
) {
  final wib = date.toUtc().add(const Duration(hours: 7));
  final weekday = wib.weekday;
  if (weekday < 1 || weekday > 5) return baseMatrix;

  final day = Day.values[weekday - 1];
  final dateStr = _formatDate(date);

  // Find pengganti entries for this date.
  final todayEntries = penggantiEntries
      .where((e) => e.date == dateStr)
      .toList();
  if (todayEntries.isEmpty) return baseMatrix;

  // Clone the matrix (deep enough for our needs).
  final result = <String, Map<Day, Map<int, List<SessionOccupancy>>>>{};
  for (final entry in baseMatrix.entries) {
    result[entry.key] = {};
    for (final dayEntry in entry.value.entries) {
      result[entry.key]![dayEntry.key] = {};
      for (final slotEntry in dayEntry.value.entries) {
        result[entry.key]![dayEntry.key]![slotEntry.key] =
            List<SessionOccupancy>.from(slotEntry.value);
      }
    }
  }

  // Find the class schedule for context.
  for (final pengganti in todayEntries) {
    // Find the base class schedule.
    final classData = classes.where((c) => c.className == pengganti.classCode);
    if (classData.isEmpty) continue;

    final dayEntry = classData.first.schedule.where((d) => d.day == day);
    final baseSessions = dayEntry.isNotEmpty
        ? dayEntry.first.sessions
        : <Session>[];

    switch (pengganti.kind) {
      case PenggantiKind.replace:
        final replaceTimes = pengganti.sessions.map((s) => s.time).toSet();
        final baseTimes = baseSessions
            .where((s) => replaceTimes.contains(s.time))
            .map((s) => s.time)
            .toSet();

        for (final roomId in result.keys.toList()) {
          final dayMap = result[roomId]?[day];
          if (dayMap == null) continue;
          for (final slotEntry in dayMap.entries) {
            slotEntry.value.removeWhere(
              (o) =>
                  (o.classCode == pengganti.classCode) &&
                  (baseTimes.contains(o.sessionTime) ||
                      replaceTimes.contains(o.sessionTime)),
            );
          }
        }

        for (final session in pengganti.sessions) {
          final room = session.room;
          final slotIndices = _findOverlappingSlots(session.time);
          result.putIfAbsent(room, () => {});
          result[room]!.putIfAbsent(day, () => {});
          for (final si in slotIndices) {
            result[room]![day]!.putIfAbsent(si, () => []);
            result[room]![day]![si]!.add(
              SessionOccupancy(
                classCode: pengganti.classCode,
                courseCode: session.courseCode,
                courseName: session.courseName,
                courseType: session.type,
                lecturer: session.lecturer,
                sessionTime: session.time,
              ),
            );
          }
        }

      case PenggantiKind.add:
        for (final session in pengganti.sessions) {
          final room = session.room;
          final slotIndices = _findOverlappingSlots(session.time);
          result.putIfAbsent(room, () => {});
          result[room]!.putIfAbsent(day, () => {});
          for (final si in slotIndices) {
            result[room]![day]!.putIfAbsent(si, () => []);
            result[room]![day]![si]!.add(
              SessionOccupancy(
                classCode: pengganti.classCode,
                courseCode: session.courseCode,
                courseName: session.courseName,
                courseType: session.type,
                lecturer: session.lecturer,
                sessionTime: session.time,
              ),
            );
          }
        }

      case PenggantiKind.info:
        // No effect on matrix.
        break;
    }
  }

  return result;
}

/// Format a DateTime as YYYY-MM-DD.
String _formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Pengganti-affected cell indicator
// ---------------------------------------------------------------------------

/// Compute the set of (roomId, Day, slotIndex) tuples affected by pengganti
/// in the current week. Used to visually distinguish pengganti-modified cells.
Set<(String, Day, int)> computePenggantiCells(List<PenggantiEntry> entries) {
  final cells = <(String, Day, int)>{};
  final now = DateTime.now();
  final wibNow = now.toUtc().add(const Duration(hours: 7));
  final monday = DateTime(
    wibNow.year,
    wibNow.month,
    wibNow.day - (wibNow.weekday - 1),
  );

  for (var i = 0; i < 5; i++) {
    final date = DateTime(monday.year, monday.month, monday.day + i);
    final day = Day.values[i];
    final dateStr = _formatDate(date);
    final dayEntries = entries.where((e) => e.date == dateStr);

    for (final entry in dayEntries) {
      if (entry.kind == PenggantiKind.info) continue;
      for (final session in entry.sessions) {
        final slotIndices = _findOverlappingSlots(session.time);
        for (final si in slotIndices) {
          cells.add((session.room, day, si));
        }
      }
    }
  }

  return cells;
}

// ---------------------------------------------------------------------------
// Room sessions — for detail view
// ---------------------------------------------------------------------------

/// A session occurrence in a room, tagged with the class it belongs to.
class RoomSession {
  const RoomSession({
    required this.classCode,
    required this.day,
    required this.session,
  });

  final String classCode;
  final Day day;
  final Session session;
}

/// Find all sessions that use a specific room, sorted by day then time.
List<RoomSession> findRoomSessions(String roomId, List<ScheduleClass> classes) {
  final results = <RoomSession>[];

  for (final cls in classes) {
    for (final daySchedule in cls.schedule) {
      for (final session in daySchedule.sessions) {
        if (session.room == roomId) {
          results.add(
            RoomSession(
              classCode: cls.className,
              day: daySchedule.day,
              session: session,
            ),
          );
        }
      }
    }
  }

  results.sort((a, b) {
    final dayCmp = a.day.index.compareTo(b.day.index);
    if (dayCmp != 0) return dayCmp;
    return a.session.time.compareTo(b.session.time);
  });

  return results;
}

// ---------------------------------------------------------------------------
// Day-specific availability helpers
// ---------------------------------------------------------------------------

/// Check if a room is occupied at any slot on the given day.
bool isRoomOccupiedOnDay(
  OccupancyMatrix matrix, {
  required String roomId,
  required Day day,
}) {
  for (var si = 0; si < kCanonicalSlots.length; si++) {
    if (isOccupied(matrix, roomId: roomId, day: day, slotIndex: si)) {
      return true;
    }
  }
  return false;
}

/// Get all occupancies for a room on a specific day (across all slots),
/// deduplicated by courseCode + sessionTime.
List<SessionOccupancy> getRoomDayOccupancies(
  OccupancyMatrix matrix, {
  required String roomId,
  required Day day,
}) {
  final results = <SessionOccupancy>[];
  for (var si = 0; si < kCanonicalSlots.length; si++) {
    results.addAll(
      getOccupancies(matrix, roomId: roomId, day: day, slotIndex: si),
    );
  }
  // Deduplicate by courseCode + sessionTime (a session can occupy multiple slots).
  final seen = <String>{};
  return results.where((o) {
    final key = '${o.courseCode}:${o.sessionTime}';
    return seen.add(key);
  }).toList();
}
