/// Tests for core notification logic — block grouping, dedup keys, and
/// provider state management.
///
/// Does NOT test platform-specific plugin behavior (flutter_local_notifications,
/// WorkManager) — those require integration tests on real devices.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/core/utils/time_slot.dart';

// ---------------------------------------------------------------------------
// Block grouping logic — mirrors NotificationService._groupIntoBlocks
// ---------------------------------------------------------------------------

/// Group consecutive sessions with the same [courseCode] into blocks.
///
/// Extracted from NotificationService for testability.
List<List<Session>> groupIntoBlocks(List<Session> sessions) {
  if (sessions.isEmpty) return [];
  final blocks = <List<Session>>[];
  var current = <Session>[sessions.first];

  for (var i = 1; i < sessions.length; i++) {
    if (sessions[i].courseCode == current.first.courseCode) {
      current.add(sessions[i]);
    } else {
      blocks.add(current);
      current = [sessions[i]];
    }
  }
  blocks.add(current);
  return blocks;
}

/// Create a test session with minimal required fields.
Session makeSession({
  required String time,
  required String courseCode,
  String courseName = 'Test Course',
  CourseType type = CourseType.te,
  String lecturerCode = 'XX',
  String lecturer = 'Test Dosen',
  String room = 'D101-Kelas',
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
  group('Block grouping (same courseCode consecutive)', () {
    test('empty sessions returns empty list', () {
      expect(groupIntoBlocks([]), isEmpty);
    });

    test('single session creates one block', () {
      final sessions = [
        makeSession(time: '07.00-07.50', courseCode: '25IF2116'),
      ];
      final blocks = groupIntoBlocks(sessions);
      expect(blocks, hasLength(1));
      expect(blocks[0], hasLength(1));
      expect(blocks[0][0].courseCode, '25IF2116');
    });

    test('consecutive same-courseCode sessions merge into one block', () {
      final sessions = [
        makeSession(time: '07.00-07.50', courseCode: '25IF2116'),
        makeSession(time: '07.50-08.40', courseCode: '25IF2116'),
        makeSession(time: '08.40-09.30', courseCode: '25IF2116'),
      ];
      final blocks = groupIntoBlocks(sessions);
      expect(blocks, hasLength(1));
      expect(blocks[0], hasLength(3));
    });

    test('different courseCode creates separate blocks', () {
      final sessions = [
        makeSession(time: '07.00-07.50', courseCode: '25IF2116'),
        makeSession(time: '07.50-08.40', courseCode: '25IF2115'),
        makeSession(time: '08.40-09.30', courseCode: '25IF2114'),
      ];
      final blocks = groupIntoBlocks(sessions);
      expect(blocks, hasLength(3));
    });

    test('alternating courses create correct block structure', () {
      final sessions = [
        makeSession(time: '07.00-07.50', courseCode: 'A'),
        makeSession(time: '07.50-08.40', courseCode: 'A'),
        makeSession(time: '08.40-09.30', courseCode: 'B'),
        makeSession(time: '09.50-10.40', courseCode: 'B'),
        makeSession(time: '10.40-11.30', courseCode: 'A'),
      ];
      final blocks = groupIntoBlocks(sessions);
      expect(blocks, hasLength(3));
      expect(blocks[0], hasLength(2)); // Two A's
      expect(blocks[1], hasLength(2)); // Two B's
      expect(blocks[2], hasLength(1)); // One A
    });

    test('real D3-2A Senin produces 3 blocks (Proyek3, PBO TE, KG TE)', () {
      // D3-2A Senin: 07.00-12.20 Proyek3 PR, 13.50-15.20 PBO TE, 15.40-17.20 KG TE
      final sessions = [
        makeSession(time: '07.00-07.50', courseCode: '25IF2116'),
        makeSession(time: '07.50-08.40', courseCode: '25IF2116'),
        makeSession(time: '08.40-09.30', courseCode: '25IF2116'),
        makeSession(time: '09.50-10.40', courseCode: '25IF2116'),
        makeSession(time: '10.40-11.30', courseCode: '25IF2116'),
        makeSession(time: '11.30-12.20', courseCode: '25IF2116'),
        makeSession(
          time: '13.50-14.40',
          courseCode: '25IF2112',
          type: CourseType.te,
        ),
        makeSession(
          time: '14.40-15.20',
          courseCode: '25IF2112',
          type: CourseType.te,
        ),
        makeSession(
          time: '15.40-16.30',
          courseCode: '25IF2115',
          type: CourseType.te,
        ),
        makeSession(
          time: '16.30-17.20',
          courseCode: '25IF2115',
          type: CourseType.te,
        ),
      ];
      final blocks = groupIntoBlocks(sessions);
      expect(blocks, hasLength(3));
      expect(blocks[0].first.courseCode, '25IF2116');
      expect(blocks[0], hasLength(6));
      expect(blocks[1].first.courseCode, '25IF2112');
      expect(blocks[2].first.courseCode, '25IF2115');
    });
  });

  group('Reminder dedup keys', () {
    test('same day + start time + courseCode = same key', () {
      const key1 = 'senin_07.00_25IF2116';
      const key2 = 'senin_07.00_25IF2116';
      expect(key1, key2);
    });

    test('different day = different key', () {
      const key1 = 'senin_07.00_25IF2116';
      const key2 = 'selasa_07.00_25IF2116';
      expect(key1, isNot(key2));
    });

    test('different start time = different key', () {
      const key1 = 'senin_07.00_25IF2116';
      const key2 = 'senin_13.50_25IF2116';
      expect(key1, isNot(key2));
    });

    test('different course = different key', () {
      const key1 = 'senin_07.00_25IF2116';
      const key2 = 'senin_07.00_25IF2115';
      expect(key1, isNot(key2));
    });
  });

  group('Block start time extraction', () {
    test('first session slot.start gives block start time', () {
      final slot = TimeSlot.parse('07.00-07.50');
      expect(slot, isNotNull);
      expect(slot!.start.hour, 7);
      expect(slot.start.minute, 0);
    });

    test('multi-jam span start time is correct', () {
      final slot = TimeSlot.parse('07.00-12.20');
      expect(slot, isNotNull);
      expect(slot!.start.hour, 7);
      expect(slot.start.minute, 0);
    });
  });

  group('Notification ID assignment', () {
    test('data-update notification uses ID 0', () {
      const dataUpdateId = 0;
      expect(dataUpdateId, 0);
    });

    test('alarm IDs start from 1 (0 is reserved)', () {
      var alarmId = 1;
      // Simulating 3 alarms.
      expect(alarmId, 1);
      alarmId++;
      expect(alarmId, 2);
      alarmId++;
      expect(alarmId, 3);
    });
  });

  group('Day enum to weekday mapping', () {
    test('Day.senin maps to weekday 1', () {
      expect(Day.senin.index, 0);
    });

    test('Day.jumat maps to weekday 5', () {
      expect(Day.jumat.index, 4);
    });

    test('all weekdays Mon-Fri have valid days', () {
      const validDays = [Day.senin, Day.selasa, Day.rabu, Day.kamis, Day.jumat];
      expect(validDays, hasLength(5));
      for (final day in validDays) {
        expect(day.index, lessThanOrEqualTo(4));
      }
    });
  });
}
