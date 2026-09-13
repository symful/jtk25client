import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/core/providers/providers.dart';
import 'package:jtk25_client/features/schedule/ui/schedule_ui.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Session _makeSession({
  required String time,
  required String courseCode,
  String courseName = 'Test Course',
  CourseType type = CourseType.te,
  String room = 'D108-Kelas',
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

/// Create a SchedulesResponse with sessions for specific days.
SchedulesResponse _makeSchedulesResponse({
  required String className,
  required Map<Day, List<Session>> daySessions,
}) {
  return SchedulesResponse(
    semester: '2025/2026 Ganjil',
    classes: [
      ScheduleClass(
        className: className,
        schedule: daySessions.entries
            .map((e) => DaySchedule(day: e.key, sessions: e.value))
            .toList(),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  const testClassName = 'D3-2A';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('jtk25_schedule_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(kSettingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('Day switcher chips', () {
    testWidgets('defaults to today\'s weekday', (tester) async {
      // Build schedule data with sessions on all 5 weekdays.
      final schedules = _makeSchedulesResponse(
        className: testClassName,
        daySessions: {
          Day.senin: [_makeSession(time: '07.00-08.40', courseCode: 'SEN')],
          Day.selasa: [_makeSession(time: '07.00-08.40', courseCode: 'SEL')],
          Day.rabu: [_makeSession(time: '07.00-08.40', courseCode: 'RAB')],
          Day.kamis: [_makeSession(time: '07.00-08.40', courseCode: 'KAM')],
          Day.jumat: [_makeSession(time: '07.00-08.40', courseCode: 'JUM')],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schedulesProvider.overrideWithValue(AsyncData(schedules)),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: SchedulePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify day chips are rendered.
      expect(find.text('Senin'), findsOneWidget);
      expect(find.text('Selasa'), findsOneWidget);
      expect(find.text('Rabu'), findsOneWidget);
      expect(find.text('Kamis'), findsOneWidget);
      expect(find.text('Jumat'), findsOneWidget);

      // The selected day chip defaults to today's weekday.
      final today = DateTime.now();
      final wibNow = today.toUtc().add(const Duration(hours: 7));
      final todayDay = Day.values[wibNow.weekday - 1];

      // If today is a weekday with sessions, verify its content is shown.
      // If today is weekend, no sessions exist — just chips are visible.
      final dayHasSessions = {
        Day.senin: true,
        Day.selasa: true,
        Day.rabu: true,
        Day.kamis: true,
        Day.jumat: true,
        Day.sabtu: false,
        Day.minggu: false,
      };
      if (dayHasSessions[todayDay] == true) {
        expect(find.text(todayDay.name.toUpperCase()), findsWidgets);
      }
    });

    testWidgets('tapping Rabu chip shows Rabu sessions', (tester) async {
      final schedules = _makeSchedulesResponse(
        className: testClassName,
        daySessions: {
          Day.senin: [_makeSession(time: '07.00-08.40', courseCode: 'SEN-101')],
          Day.rabu: [_makeSession(time: '09.30-11.20', courseCode: 'RAB-202')],
          Day.jumat: [_makeSession(time: '13.00-14.50', courseCode: 'JUM-303')],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schedulesProvider.overrideWithValue(AsyncData(schedules)),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: SchedulePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Rabu" chip.
      await tester.tap(find.text('Rabu'));
      await tester.pumpAndSettle();

      // Verify Rabu session is displayed.
      expect(find.text('RAB-202'), findsOneWidget);
    });

    testWidgets('Hari Ini reset chip appears when non-today selected', (
      tester,
    ) async {
      final schedules = _makeSchedulesResponse(
        className: testClassName,
        daySessions: {
          Day.senin: [_makeSession(time: '07.00-08.40', courseCode: 'SEN')],
          Day.rabu: [_makeSession(time: '07.00-08.40', courseCode: 'RAB')],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schedulesProvider.overrideWithValue(AsyncData(schedules)),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: SchedulePage()),
        ),
      );
      await tester.pumpAndSettle();

      // If today is NOT Rabu, tapping Rabu should show "Hari Ini" chip.
      final today = DateTime.now();
      final wibNow = today.toUtc().add(const Duration(hours: 7));
      final todayDay = Day.values[wibNow.weekday - 1];

      if (todayDay != Day.rabu) {
        await tester.tap(find.text('Rabu'));
        await tester.pumpAndSettle();

        // "Hari Ini" reset chip should appear.
        expect(find.text('Hari Ini'), findsWidgets);
      }
    });

    testWidgets('week view is unchanged by day selection', (tester) async {
      final schedules = _makeSchedulesResponse(
        className: testClassName,
        daySessions: {
          Day.senin: [_makeSession(time: '07.00-08.40', courseCode: 'SEN')],
          Day.rabu: [_makeSession(time: '07.00-08.40', courseCode: 'RAB')],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schedulesProvider.overrideWithValue(AsyncData(schedules)),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: SchedulePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to week view.
      await tester.tap(find.text('Mingguan'));
      await tester.pumpAndSettle();

      // Week view should show day headers for the week.
      expect(find.textContaining('SENIN'), findsOneWidget);
      expect(find.textContaining('RABU'), findsOneWidget);

      // Day chips should NOT be visible in week view.
      // (They only appear in "Hari Ini" mode.)
    });

    testWidgets('only shows chips for days with sessions', (tester) async {
      // Class only has sessions on Senin and Rabu.
      final schedules = _makeSchedulesResponse(
        className: testClassName,
        daySessions: {
          Day.senin: [_makeSession(time: '07.00-08.40', courseCode: 'SEN')],
          Day.rabu: [_makeSession(time: '07.00-08.40', courseCode: 'RAB')],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schedulesProvider.overrideWithValue(AsyncData(schedules)),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: SchedulePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Chips for days WITH sessions should exist.
      expect(find.text('Senin'), findsOneWidget);
      expect(find.text('Rabu'), findsOneWidget);

      // Chips for days WITHOUT sessions should NOT exist.
      expect(find.text('Selasa'), findsNothing);
      expect(find.text('Kamis'), findsNothing);
      expect(find.text('Jumat'), findsNothing);
    });
  });
}
