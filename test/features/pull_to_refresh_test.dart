/// Widget tests for pull-to-refresh on all list screens.
///
/// Verifies that RefreshIndicator wraps the scrollable content on
/// announcements and schedule screens, and that AppBar refresh buttons exist.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jtk25_client/core/models/announcement.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/core/providers/providers.dart';
import 'package:jtk25_client/features/announcements/data/announcements_data.dart';
import 'package:jtk25_client/features/announcements/providers/announcements_providers.dart';
import 'package:jtk25_client/features/announcements/ui/announcements_ui.dart';
import 'package:jtk25_client/features/schedule/ui/schedule_ui.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Announcement _makeAnnouncement({String id = '1', String title = 'Test'}) {
  return Announcement(
    id: id,
    title: title,
    body: 'Body',
    createdAt: DateTime.now().toIso8601String(),
  );
}

Session _makeSession({
  String time = '07.00-08.40',
  String courseCode = 'TEST',
}) {
  return Session(
    time: time,
    courseCode: courseCode,
    courseName: 'Test Course',
    type: CourseType.te,
    lecturerCode: 'XX',
    lecturer: 'Test Dosen',
    room: 'D108-Kelas',
  );
}

SchedulesResponse _makeSchedulesResponse({String className = 'D3-2A'}) {
  return SchedulesResponse(
    semester: '2025/2026 Ganjil',
    classes: [
      ScheduleClass(
        className: className,
        schedule: [
          DaySchedule(day: Day.senin, sessions: [_makeSession()]),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  late AnnouncementsSeen fakeSeen;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id');
    tempDir = await Directory.systemTemp.createTemp('jtk25_refresh_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(kSettingsBoxName);
    fakeSeen = AnnouncementsSeen();
    await fakeSeen.init();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('Announcements - RefreshIndicator', () {
    testWidgets('RefreshIndicator wraps the announcements list', (
      tester,
    ) async {
      final items = [
        _makeAnnouncement(id: '1', title: 'Pengumuman 1'),
        _makeAnnouncement(id: '2', title: 'Pengumuman 2'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Core provider — UI watches this directly for loading/error/data.
            announcementsProvider.overrideWithValue(AsyncData(items)),
            // Feature-local derivation — sync Provider, pass list directly.
            filteredAnnouncementsProvider.overrideWithValue(items),
            announcementsSeenProvider.overrideWithValue(fakeSeen),
          ],
          child: const MaterialApp(home: AnnouncementsListPage()),
        ),
      );
      await tester.pumpAndSettle();

      // RefreshIndicator should be present.
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // AppBar should have a refresh IconButton.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
    });
  });

  group('Schedule - RefreshIndicator', () {
    testWidgets('RefreshIndicator wraps the schedule view', (tester) async {
      final schedules = _makeSchedulesResponse();

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

      // RefreshIndicator should be present.
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // AppBar should have a refresh IconButton.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
    });
  });
}
