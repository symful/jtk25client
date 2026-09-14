import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/core/utils/time_slot.dart';

void main() {
  group('WibTime.parse', () {
    test('parses standard time', () {
      final t = WibTime.parse('07.00');
      expect(t, isNotNull);
      expect(t!.hour, 7);
      expect(t.minute, 0);
      expect(t.totalMinutes, 420);
    });

    test('parses 23.59', () {
      final t = WibTime.parse('23.59');
      expect(t, isNotNull);
      expect(t!.hour, 23);
      expect(t.minute, 59);
    });

    test('returns null for invalid format', () {
      expect(WibTime.parse('7:00'), isNull);
      expect(WibTime.parse('abc'), isNull);
      expect(WibTime.parse(''), isNull);
      expect(WibTime.parse('25.00'), isNull); // hour > 23
    });
  });

  group('TimeSlot.parse', () {
    test('parses single-jam slot 07.00-07.50', () {
      final slot = TimeSlot.parse('07.00-07.50');
      expect(slot, isNotNull);
      expect(slot!.start.hour, 7);
      expect(slot.start.minute, 0);
      expect(slot.end.hour, 7);
      expect(slot.end.minute, 50);
      expect(slot.durationMinutes, 50);
    });

    test('parses multi-jam span 07.00-12.20', () {
      final slot = TimeSlot.parse('07.00-12.20');
      expect(slot, isNotNull);
      expect(slot!.start.totalMinutes, 420);
      expect(slot.end.totalMinutes, 740);
      expect(slot.durationMinutes, 320);
    });

    test('parses 11.30-15.20 span', () {
      final slot = TimeSlot.parse('11.30-15.20');
      expect(slot, isNotNull);
      expect(slot!.start.totalMinutes, 690);
      expect(slot.end.totalMinutes, 920);
      expect(slot.durationMinutes, 230);
    });

    test('parses jam-9 40-minute slot 14.40-15.20', () {
      final slot = TimeSlot.parse('14.40-15.20');
      expect(slot, isNotNull);
      expect(slot!.durationMinutes, 40);
    });

    test('parses 15.40-16.30 (jam 10)', () {
      final slot = TimeSlot.parse('15.40-16.30');
      expect(slot, isNotNull);
      expect(slot!.durationMinutes, 50);
    });

    test('parses 16.30-17.20 (jam 11)', () {
      final slot = TimeSlot.parse('16.30-17.20');
      expect(slot, isNotNull);
      expect(slot!.durationMinutes, 50);
    });

    test('parses 17.20-18.10 (jam 12)', () {
      final slot = TimeSlot.parse('17.20-18.10');
      expect(slot, isNotNull);
      expect(slot!.durationMinutes, 50);
    });

    test('returns null for inverted range', () {
      expect(TimeSlot.parse('15.20-14.40'), isNull);
    });

    test('returns null for bad format', () {
      expect(TimeSlot.parse('hello'), isNull);
      expect(TimeSlot.parse('07.00'), isNull);
      expect(TimeSlot.parse(''), isNull);
    });
  });

  group('TimeSlot.containsMinutes', () {
    test('inclusive start', () {
      final slot = TimeSlot.parse('07.00-07.50')!;
      expect(slot.containsMinutes(420), isTrue); // 07.00
    });

    test('exclusive end', () {
      final slot = TimeSlot.parse('07.00-07.50')!;
      expect(slot.containsMinutes(470), isFalse); // 07.50 exactly
    });

    test('inside range', () {
      final slot = TimeSlot.parse('07.00-12.20')!;
      expect(slot.containsMinutes(600), isTrue); // 10.00
    });

    test('before range', () {
      final slot = TimeSlot.parse('07.00-07.50')!;
      expect(slot.containsMinutes(419), isFalse);
    });
  });

  group('isBreak', () {
    test('detects 09.30-09.50 break', () {
      expect(isBreak(570), isTrue); // 09.30
      expect(isBreak(585), isTrue); // 09.45
      expect(isBreak(590), isFalse); // 09.50 (exclusive)
    });

    test('detects 12.20-13.00 break', () {
      expect(isBreak(740), isTrue); // 12.20
      expect(isBreak(760), isTrue); // 12.40
      expect(isBreak(780), isFalse); // 13.00
    });

    test('detects 15.20-15.40 break', () {
      expect(isBreak(920), isTrue); // 15.20
      expect(isBreak(930), isTrue); // 15.30
      expect(isBreak(940), isFalse); // 15.40
    });

    test('not break outside break times', () {
      expect(isBreak(420), isFalse); // 07.00
      expect(isBreak(900), isFalse); // 15.00
    });
  });

  group('currentSlot', () {
    // Helper to create a UTC DateTime at a given WIB time.
    // WIB = UTC+7, so to get WIB 08:00 → UTC 01:00.
    DateTime wibToUtc(int hour, int minute, {int day = 15}) {
      return DateTime.utc(2026, 9, day, hour - 7, minute);
    }

    final sessions = [
      _makeSession('07.00-12.20', '25IF2116'),
      _makeSession('13.50-15.20', '25IF2112'),
      _makeSession('15.40-17.20', '25IF2115'),
    ];

    test('returns session during active time', () {
      final now = wibToUtc(8, 0);
      final result = currentSlot(now, sessions);
      expect(result, isNotNull);
      expect(result!.courseCode, '25IF2116');
    });

    test('returns session at exact start', () {
      final now = wibToUtc(7, 0);
      final result = currentSlot(now, sessions);
      expect(result, isNotNull);
      expect(result!.courseCode, '25IF2116');
    });

    test('returns null during break (12.20-13.00)', () {
      final now = wibToUtc(12, 30);
      final result = currentSlot(now, sessions);
      expect(result, isNull);
    });

    test('returns null before first session', () {
      final now = wibToUtc(6, 0);
      final result = currentSlot(now, sessions);
      expect(result, isNull);
    });

    test('returns null after last session', () {
      final now = wibToUtc(18, 0);
      final result = currentSlot(now, sessions);
      expect(result, isNull);
    });

    test('returns null for empty sessions', () {
      final now = wibToUtc(10, 0);
      final result = currentSlot(now, []);
      expect(result, isNull);
    });

    test('returns second session during its time', () {
      final now = wibToUtc(14, 0);
      final result = currentSlot(now, sessions);
      expect(result, isNotNull);
      expect(result!.courseCode, '25IF2112');
    });

    test('returns third session during its time', () {
      final now = wibToUtc(16, 0);
      final result = currentSlot(now, sessions);
      expect(result, isNotNull);
      expect(result!.courseCode, '25IF2115');
    });
  });

  group('nextSlotStart', () {
    DateTime wibToUtc(int hour, int minute) {
      return DateTime.utc(2026, 9, 15, hour - 7, minute);
    }

    final sessions = [
      _makeSession('07.00-12.20', '25IF2116'),
      _makeSession('13.50-15.20', '25IF2112'),
      _makeSession('15.40-17.20', '25IF2115'),
    ];

    test('returns next session start', () {
      final now = wibToUtc(8, 0);
      final result = nextSlotStart(now, sessions);
      expect(result, isNotNull);
      expect(result!.hour, 13);
      expect(result.minute, 50);
    });

    test('returns null when no sessions remain', () {
      final now = wibToUtc(18, 0);
      final result = nextSlotStart(now, sessions);
      expect(result, isNull);
    });

    test('returns first session if before all', () {
      final now = wibToUtc(6, 0);
      final result = nextSlotStart(now, sessions);
      expect(result, isNotNull);
      expect(result!.hour, 7);
      expect(result.minute, 0);
    });

    test('returns null for empty sessions', () {
      final now = wibToUtc(10, 0);
      final result = nextSlotStart(now, []);
      expect(result, isNull);
    });
  });

  group('dayToDate', () {
    test('returns same day if today matches', () {
      // 2026-09-14 is a Monday.
      final ref = DateTime(2026, 9, 14);
      final result = dayToDate(Day.senin, reference: ref);
      expect(result.weekday, DateTime.monday);
    });

    test('returns next occurrence', () {
      // 2026-09-14 is Monday; find next Tuesday.
      final ref = DateTime(2026, 9, 14);
      final result = dayToDate(Day.selasa, reference: ref);
      expect(result.weekday, DateTime.tuesday);
      expect(result.day, 15);
    });

    test('handles minggu (Sunday)', () {
      // 2026-09-15 is Tuesday; find next Sunday.
      final ref = DateTime(2026, 9, 15);
      final result = dayToDate(Day.minggu, reference: ref);
      expect(result.weekday, DateTime.sunday);
    });
  });

  group('WibTime equality', () {
    test('equal times are equal', () {
      expect(WibTime(7, 0), equals(WibTime(7, 0)));
      expect(WibTime(7, 0).hashCode, equals(WibTime(7, 0).hashCode));
    });

    test('different times are not equal', () {
      expect(WibTime(7, 0) == WibTime(7, 50), isFalse);
    });
  });

  group('TimeSlot equality', () {
    test('equal slots are equal', () {
      expect(
        TimeSlot.parse('07.00-07.50'),
        equals(TimeSlot.parse('07.00-07.50')),
      );
    });
  });
}

Session _makeSession(String time, String courseCode) {
  return Session(
    time: time,
    courseCode: courseCode,
    courseName: 'Test Course',
    type: CourseType.te,
    lecturerCode: 'AB',
    lecturer: 'Test Lecturer',
    room: 'D108-Kelas',
  );
}
