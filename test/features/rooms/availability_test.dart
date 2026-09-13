import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/pengganti.dart';
import 'package:jtk25_client/core/models/room.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/features/rooms/data/rooms_data.dart';

/// Helper to build a minimal ScheduleClass with one day/sessions.
ScheduleClass _makeClass({
  required String className,
  required Day day,
  required List<Session> sessions,
}) {
  return ScheduleClass(
    className: className,
    schedule: [DaySchedule(day: day, sessions: sessions)],
  );
}

Session _makeSession({
  required String time,
  required String room,
  required String courseCode,
  String courseName = 'Test Course',
  CourseType type = CourseType.te,
  String lecturerCode = 'XX',
  String lecturer = 'Test Dosen',
}) {
  return Session(
    time: time,
    courseCode: courseCode,
    courseName: courseName,
    type: type,
    lecturerCode: lecturerCode,
    lecturer: lecturer,
    room: room,
  );
}

void main() {
  group('buildOccupancyMatrix', () {
    test('single session occupies correct slots', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-08.40',
              room: 'D108-Kelas',
              courseCode: '25IF2111',
            ),
          ],
        ),
      ];

      final matrix = buildOccupancyMatrix(classes);

      // 07.00-08.40 overlaps slots 0 (07.00-07.50) and 1 (07.50-08.40)
      expect(
        isOccupied(matrix, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
      expect(
        isOccupied(matrix, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 1),
        isTrue,
      );
      expect(
        isOccupied(matrix, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 2),
        isFalse,
      );
    });

    test('long span occupies multiple slots', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-12.20',
              room: 'H501-Lab. TI',
              courseCode: '25IF2116',
            ),
          ],
        ),
      ];

      final matrix = buildOccupancyMatrix(classes);

      // 07.00-12.20 should occupy slots 0-5 (all morning slots)
      for (var i = 0; i <= 5; i++) {
        expect(
          isOccupied(
            matrix,
            roomId: 'H501-Lab. TI',
            day: Day.senin,
            slotIndex: i,
          ),
          isTrue,
          reason: 'Slot $i should be occupied',
        );
      }
      // Slot 6 (13.00-13.50) should NOT be occupied
      expect(
        isOccupied(
          matrix,
          roomId: 'H501-Lab. TI',
          day: Day.senin,
          slotIndex: 6,
        ),
        isFalse,
      );
    });

    test('empty classes produce empty matrix', () {
      final matrix = buildOccupancyMatrix([]);
      expect(matrix, isEmpty);
    });

    test('multiple classes in same room same day creates overlap', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: '25IF2111',
            ),
          ],
        ),
        _makeClass(
          className: 'D3-3B',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: '25IF2110',
            ),
          ],
        ),
      ];

      final matrix = buildOccupancyMatrix(classes);

      expect(
        hasOverlap(matrix, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
      expect(
        getOccupancies(
          matrix,
          roomId: 'D108-Kelas',
          day: Day.senin,
          slotIndex: 0,
        ),
        hasLength(2),
      );
    });
  });

  group('getOccupancies', () {
    test('returns empty list for unoccupied cell', () {
      final matrix = buildOccupancyMatrix([]);
      expect(
        getOccupancies(
          matrix,
          roomId: 'D108-Kelas',
          day: Day.senin,
          slotIndex: 0,
        ),
        isEmpty,
      );
    });
  });

  group('hasOverlap', () {
    test('returns false for single occupancy', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];
      final matrix = buildOccupancyMatrix(classes);
      expect(
        hasOverlap(matrix, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isFalse,
      );
    });
  });

  group('currentSlotIndex', () {
    test('returns slot index during teaching hours', () {
      // WIB 08:00 = UTC 01:00
      final now = DateTime.utc(2026, 9, 15, 1, 0);
      expect(currentSlotIndex(now), 1); // slot 1: 07.50-08.40
    });

    test('returns null during break 09.30-09.50', () {
      // WIB 09.40 = UTC 02:40
      final now = DateTime.utc(2026, 9, 15, 2, 40);
      expect(currentSlotIndex(now), isNull);
    });

    test('returns null during break 12.20-13.00', () {
      // WIB 12.30 = UTC 05:30
      final now = DateTime.utc(2026, 9, 15, 5, 30);
      expect(currentSlotIndex(now), isNull);
    });

    test('returns null during break 15.20-15.40', () {
      // WIB 15.30 = UTC 08:30
      final now = DateTime.utc(2026, 9, 15, 8, 30);
      expect(currentSlotIndex(now), isNull);
    });

    test('returns null before teaching hours', () {
      // WIB 06.00 = UTC 23:00 (previous day)
      final now = DateTime.utc(2026, 9, 14, 23, 0);
      expect(currentSlotIndex(now), isNull);
    });

    test('returns null after teaching hours', () {
      // WIB 18.00 = UTC 11:00
      final now = DateTime.utc(2026, 9, 15, 11, 0);
      expect(currentSlotIndex(now), isNull);
    });
  });

  group('currentWorkDay', () {
    test('returns Day.senin for Monday', () {
      // 2026-09-14 is Monday
      final now = DateTime.utc(2026, 9, 14, 1, 0);
      expect(currentWorkDay(now), Day.senin);
    });

    test('returns null for Saturday', () {
      // 2026-09-19 is Saturday
      final now = DateTime.utc(2026, 9, 19, 1, 0);
      expect(currentWorkDay(now), isNull);
    });

    test('returns null for Sunday', () {
      // 2026-09-20 is Sunday
      final now = DateTime.utc(2026, 9, 20, 1, 0);
      expect(currentWorkDay(now), isNull);
    });
  });

  group('isAvailableNow', () {
    test('returns true on weekend', () {
      final matrix = buildOccupancyMatrix([]);
      // Saturday
      final now = DateTime.utc(2026, 9, 19, 1, 0);
      expect(isAvailableNow(matrix, roomId: 'D108-Kelas', now: now), isTrue);
    });

    test('returns true during break', () {
      final matrix = buildOccupancyMatrix([]);
      // WIB 09.40 = break
      final now = DateTime.utc(2026, 9, 15, 2, 40);
      expect(isAvailableNow(matrix, roomId: 'D108-Kelas', now: now), isTrue);
    });

    test('returns false when room is occupied', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];
      final matrix = buildOccupancyMatrix(classes);
      // WIB 07.10 = UTC 00:10, Monday = senin, slot 0 occupied
      final now = DateTime.utc(2026, 9, 14, 0, 10);
      expect(isAvailableNow(matrix, roomId: 'D108-Kelas', now: now), isFalse);
    });

    test('returns true when room is free', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];
      final matrix = buildOccupancyMatrix(classes);
      // WIB 08.00 = UTC 01:00, slot 1 NOT occupied for D108
      final now = DateTime.utc(2026, 9, 14, 1, 0);
      expect(isAvailableNow(matrix, roomId: 'D108-Kelas', now: now), isTrue);
    });
  });

  group('applyPenggantiToDate', () {
    test('replace removes base occupancy and adds pengganti', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: '25IF2111',
              courseName: 'Matdisk',
            ),
          ],
        ),
      ];

      final baseMatrix = buildOccupancyMatrix(classes);

      // 2026-09-14 is Monday
      final pengganti = [
        PenggantiEntry(
          id: 'pg-1',
          classCode: 'D3-3A',
          date: '2026-09-14',
          kind: PenggantiKind.replace,
          sessions: [
            Session(
              time: '07.00-07.50',
              courseCode: '25IF2111',
              courseName: 'Matdisk (Pengganti)',
              type: CourseType.te,
              lecturerCode: 'XX',
              lecturer: 'Replacement',
              room: 'D112-Kelas',
            ),
          ],
        ),
      ];

      final result = applyPenggantiToDate(
        baseMatrix,
        pengganti,
        classes,
        DateTime.utc(2026, 9, 14),
      );

      expect(
        isOccupied(result, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isFalse,
      );
      expect(
        isOccupied(result, roomId: 'D112-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
    });

    test('add appends new session without removing base', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: '25IF2111',
            ),
          ],
        ),
      ];

      final baseMatrix = buildOccupancyMatrix(classes);

      final pengganti = [
        PenggantiEntry(
          id: 'pg-2',
          classCode: 'D3-3A',
          date: '2026-09-14',
          kind: PenggantiKind.add,
          sessions: [
            Session(
              time: '17.20-18.10',
              courseCode: '25IF9999',
              courseName: 'Extra',
              type: CourseType.te,
              lecturerCode: 'XX',
              lecturer: 'Extra',
              room: 'D108-Kelas',
            ),
          ],
        ),
      ];

      final result = applyPenggantiToDate(
        baseMatrix,
        pengganti,
        classes,
        DateTime.utc(2026, 9, 14),
      );

      expect(
        isOccupied(result, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
      expect(
        isOccupied(result, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
    });

    test('info does not affect matrix', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];

      final baseMatrix = buildOccupancyMatrix(classes);

      final pengganti = [
        PenggantiEntry(
          id: 'pg-3',
          classCode: 'D3-3A',
          date: '2026-09-14',
          kind: PenggantiKind.info,
          note: 'Libur nasional',
        ),
      ];

      final result = applyPenggantiToDate(
        baseMatrix,
        pengganti,
        classes,
        DateTime.utc(2026, 9, 14),
      );

      // Matrix should be unchanged
      expect(
        isOccupied(result, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
    });

    test('weekend date returns base matrix unchanged', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];

      final baseMatrix = buildOccupancyMatrix(classes);

      final pengganti = [
        PenggantiEntry(
          id: 'pg-4',
          classCode: 'D3-3A',
          date: '2026-09-19', // Saturday
          kind: PenggantiKind.replace,
          sessions: [
            Session(
              time: '07.00-07.50',
              courseCode: 'B',
              courseName: 'Replaced',
              type: CourseType.te,
              lecturerCode: 'XX',
              lecturer: 'X',
              room: 'D999-Kelas',
            ),
          ],
        ),
      ];

      final result = applyPenggantiToDate(
        baseMatrix,
        pengganti,
        classes,
        DateTime.utc(2026, 9, 19),
      );

      // Should be identical to base (weekend)
      expect(
        isOccupied(result, roomId: 'D108-Kelas', day: Day.senin, slotIndex: 0),
        isTrue,
      );
      expect(
        isOccupied(result, roomId: 'D999-Kelas', day: Day.senin, slotIndex: 0),
        isFalse,
      );
    });
  });

  group('findRoomSessions', () {
    test('finds sessions in a room across classes', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
        _makeClass(
          className: 'D3-3B',
          day: Day.selasa,
          sessions: [
            _makeSession(
              time: '08.40-09.30',
              room: 'D108-Kelas',
              courseCode: 'B',
            ),
          ],
        ),
      ];

      final sessions = findRoomSessions('D108-Kelas', classes);
      expect(sessions, hasLength(2));
      expect(sessions[0].classCode, 'D3-3A');
      expect(sessions[1].classCode, 'D3-3B');
    });

    test('returns empty for non-existent room', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];

      final sessions = findRoomSessions('D999-Kelas', classes);
      expect(sessions, isEmpty);
    });

    test('sorts by day then time', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.jumat,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '13.00-13.50',
              room: 'D108-Kelas',
              courseCode: 'B',
            ),
          ],
        ),
      ];

      final sessions = findRoomSessions('D108-Kelas', classes);
      expect(sessions, hasLength(2));
      expect(sessions[0].day, Day.senin);
      expect(sessions[1].day, Day.jumat);
    });
  });

  group('countAvailableRooms', () {
    test('counts available rooms', () {
      final classes = [
        _makeClass(
          className: 'D3-3A',
          day: Day.senin,
          sessions: [
            _makeSession(
              time: '07.00-07.50',
              room: 'D108-Kelas',
              courseCode: 'A',
            ),
          ],
        ),
      ];
      final matrix = buildOccupancyMatrix(classes);

      final rooms = [
        Room(id: 'D108-Kelas', name: 'D108'),
        Room(id: 'D112-Kelas', name: 'D112'),
      ];

      // WIB 07.10 = UTC 00:10, Monday, slot 0
      final now = DateTime.utc(2026, 9, 14, 0, 10);
      expect(
        countAvailableRooms(matrix, rooms: rooms, now: now),
        1,
      ); // D112 only
    });
  });
}
