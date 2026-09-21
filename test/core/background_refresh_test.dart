/// Tests for background refresh logic — workmanager periodic task.
///
/// Tests pure data parsing, configuration, and Hive cache-reading logic.
/// Does NOT test actual plugin scheduling (flutter_local_notifications
/// and workmanager require real devices).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/core/cache/offline_cache.dart';
import 'package:jtk25_client/core/models/calendar.dart';
import 'package:jtk25_client/core/models/pengganti.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/core/notifications/background_refresh.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

/// A full week schedule (Mon–Fri) with one session per day.
List<DaySchedule> makeFullWeekSchedule() {
  return [
    DaySchedule(
      day: Day.senin,
      sessions: [makeSession(time: '07.00-08.40', courseCode: '25IF2116')],
    ),
    DaySchedule(
      day: Day.selasa,
      sessions: [makeSession(time: '09.00-10.40', courseCode: '25IF2112')],
    ),
    DaySchedule(
      day: Day.rabu,
      sessions: [makeSession(time: '13.00-14.40', courseCode: '25IF2115')],
    ),
    DaySchedule(
      day: Day.kamis,
      sessions: [makeSession(time: '07.00-08.40', courseCode: '25IF2110')],
    ),
    DaySchedule(
      day: Day.jumat,
      sessions: [makeSession(time: '09.00-10.40', courseCode: '25IF2114')],
    ),
  ];
}

void main() {
  // -----------------------------------------------------------------------
  // Background refresh configuration
  // -----------------------------------------------------------------------
  group('Background refresh configuration', () {
    test('refresh interval is 6 hours', () {
      expect(kBackgroundRefreshInterval, const Duration(hours: 6));
    });

    test('unique name is stable', () {
      expect(kBackgroundRefreshUniqueName, 'jtk25-reminder-refresh');
    });

    test('task name is stable', () {
      expect(kBackgroundRefreshTaskName, 'reminderRefresh');
    });
  });

  // -----------------------------------------------------------------------
  // Platform guard
  // -----------------------------------------------------------------------
  group('Platform guard', () {
    test('Platform.isAndroid is false on Windows (test host)', () {
      // The callbackDispatcher guards with `if (!Platform.isAndroid) return true`.
      // On Windows (where flutter test runs), this guard always triggers.
      // This test documents that the guard works correctly on non-Android hosts.
      expect(Platform.isAndroid, false);
    });
  });

  // -----------------------------------------------------------------------
  // Cache payload parsing — SchedulesResponse
  // -----------------------------------------------------------------------
  group('SchedulesResponse from cache', () {
    test('parses valid schedule payload', () {
      final payload = {
        'semester': '2025/2026',
        'classes': [
          {
            'class_name': 'D3-2A',
            'schedule': [
              {
                'day': 'SENIN',
                'sessions': [
                  {
                    'time': '07.00-08.40',
                    'course_code': '25IF2116',
                    'course_name': 'Proyek 3',
                    'type': 'PR',
                    'lecturer_code': 'XX',
                    'lecturer': 'Test',
                    'room': 'D108-Kelas',
                  },
                ],
              },
            ],
          },
        ],
      };

      final response = SchedulesResponse.fromJson(payload);
      expect(response.semester, '2025/2026');
      expect(response.classes, hasLength(1));
      expect(response.classes.first.className, 'D3-2A');
      expect(response.classes.first.schedule, hasLength(1));
      expect(response.classes.first.schedule.first.sessions, hasLength(1));
      expect(
        response.classes.first.schedule.first.sessions.first.courseCode,
        '25IF2116',
      );
    });

    test('class selection with firstWhere + orElse', () {
      final classes = [
        ScheduleClass(className: 'D3-2A', schedule: makeFullWeekSchedule()),
        ScheduleClass(className: 'D4-2B', schedule: makeFullWeekSchedule()),
      ];

      final match = classes.firstWhere(
        (c) => c.className == 'D4-2B',
        orElse: () => classes.first,
      );
      expect(match.className, 'D4-2B');
    });

    test('class selection falls back to first when no match', () {
      final classes = [
        ScheduleClass(className: 'D3-2A', schedule: makeFullWeekSchedule()),
        ScheduleClass(className: 'D4-2B', schedule: makeFullWeekSchedule()),
      ];

      final match = classes.firstWhere(
        (c) => c.className == 'NOTEXIST',
        orElse: () => classes.first,
      );
      expect(match.className, 'D3-2A');
    });

    test('empty classes list', () {
      final response = SchedulesResponse.fromJson({
        'semester': '2025',
        'classes': <Map<String, dynamic>>[],
      });
      expect(response.classes, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Cache payload parsing — JtkCalendar
  // -----------------------------------------------------------------------
  group('JtkCalendar from cache', () {
    test('parses calendar events', () {
      final items = [
        {
          'id': 1,
          'title': 'Libur Nasional',
          'date': '2026-01-01',
          'end_date': '2026-01-01',
          'location': 'Kampus',
        },
        {
          'id': 2,
          'title': 'Seminar',
          'date': '2026-09-15T09:00:00',
          'end_date': '2026-09-15T12:00:00',
        },
      ];

      final events = JtkCalendar.listFromJson(items);
      expect(events, hasLength(2));
      expect(events.first.title, 'Libur Nasional');
      expect(events.first.location, 'Kampus');
      expect(events.last.title, 'Seminar');
    });

    test('null input returns empty list', () {
      expect(JtkCalendar.listFromJson(null), isEmpty);
    });

    test('non-list input returns empty list', () {
      expect(JtkCalendar.listFromJson('invalid'), isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Cache payload parsing — PenggantiEntry
  // -----------------------------------------------------------------------
  group('PenggantiEntry from cache', () {
    test('parses pengganti entries with sessions', () {
      final items = [
        {
          'id': 1,
          'class_code': 'D3-2A',
          'date': '2026-09-21',
          'kind': 'replace',
          'sessions': [
            {
              'time': '07.00-08.40',
              'course_code': '25IF2116',
              'course_name': 'Proyek 3',
              'type': 'PR',
              'lecturer_code': 'XX',
              'lecturer': 'Test',
              'room': 'D108-Kelas',
            },
          ],
        },
      ];

      final entries = PenggantiEntry.listFromJson(items);
      expect(entries, hasLength(1));
      expect(entries.first.classCode, 'D3-2A');
      expect(entries.first.date, '2026-09-21');
      expect(entries.first.kind, PenggantiKind.replace);
      expect(entries.first.sessions, hasLength(1));
    });

    test('null input returns empty list', () {
      expect(PenggantiEntry.listFromJson(null), isEmpty);
    });

    test('parses add and info kinds', () {
      final items = [
        {
          'id': 1,
          'class_code': 'D3-2A',
          'date': '2026-09-22',
          'kind': 'add',
          'sessions': <Map<String, dynamic>>[],
        },
        {
          'id': 2,
          'class_code': 'D3-2A',
          'date': '2026-09-23',
          'kind': 'info',
          'note': 'Ujian Tengah Semester',
          'sessions': <Map<String, dynamic>>[],
        },
      ];

      final entries = PenggantiEntry.listFromJson(items);
      expect(entries, hasLength(2));
      expect(entries[0].kind, PenggantiKind.add);
      expect(entries[1].kind, PenggantiKind.info);
      expect(entries[1].note, 'Ujian Tengah Semester');
    });
  });

  // -----------------------------------------------------------------------
  // Cache payload parsing — OfflineCache integration
  // -----------------------------------------------------------------------
  group('OfflineCache loadJson', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('save and load schedules round-trip', () async {
      final cache = OfflineCache();
      await cache.init();

      final data = {
        'semester': '2025/2026',
        'classes': [
          {'class_name': 'D3-2A', 'schedule': <Map<String, dynamic>>[]},
        ],
      };
      await cache.save(CacheKey.schedules, data);

      final loaded = cache.loadJson(CacheKey.schedules);
      expect(loaded, isA<Map<String, dynamic>>());
      final response = SchedulesResponse.fromJson(
        loaded as Map<String, dynamic>,
      );
      expect(response.classes.first.className, 'D3-2A');
    });

    test('save and load calendar round-trip', () async {
      final cache = OfflineCache();
      await cache.init();

      final data = {
        'data': [
          {
            'id': 1,
            'title': 'Test Event',
            'date': '2026-01-01',
            'end_date': '2026-01-01',
          },
        ],
      };
      await cache.save(CacheKey.calendar, data);

      final loaded = cache.loadJson(CacheKey.calendar);
      expect(loaded, isA<Map<String, dynamic>>());
      final events = JtkCalendar.listFromJson(
        (loaded as Map<String, dynamic>)['data'],
      );
      expect(events, hasLength(1));
      expect(events.first.title, 'Test Event');
    });

    test('save and load pengganti round-trip', () async {
      final cache = OfflineCache();
      await cache.init();

      final data = {
        'data': [
          {
            'id': 1,
            'class_code': 'D3-2A',
            'date': '2026-09-21',
            'kind': 'replace',
            'sessions': <Map<String, dynamic>>[],
          },
        ],
      };
      await cache.save(CacheKey.pengganti, data);

      final loaded = cache.loadJson(CacheKey.pengganti);
      expect(loaded, isA<Map<String, dynamic>>());
      final entries = PenggantiEntry.listFromJson(
        (loaded as Map<String, dynamic>)['data'],
      );
      expect(entries, hasLength(1));
      expect(entries.first.classCode, 'D3-2A');
    });

    test('empty cache returns null', () {
      final cache = OfflineCache();
      // Not initialized — loadJson returns null.
      expect(cache.loadJson(CacheKey.schedules), isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Hive settings reading — enabled check
  // -----------------------------------------------------------------------
  group('Hive settings reading', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('reads notifications_enabled from settings box', () async {
      final box = await Hive.openBox(kSettingsBoxName);
      await box.put(SettingsKeys.notificationsEnabled, true);

      final enabled =
          box.get(SettingsKeys.notificationsEnabled) as bool? ?? false;
      expect(enabled, true);
    });

    test('defaults to false when notifications_enabled not set', () async {
      final box = await Hive.openBox(kSettingsBoxName);

      final enabled =
          box.get(SettingsKeys.notificationsEnabled) as bool? ?? false;
      expect(enabled, false);
    });

    test('reads selected_class from settings box', () async {
      final box = await Hive.openBox(kSettingsBoxName);
      await box.put(SettingsKeys.selectedClass, 'D4-2B');

      final selected = box.get(SettingsKeys.selectedClass) as String? ?? '';
      expect(selected, 'D4-2B');
    });

    test('defaults to empty string when selected_class not set', () async {
      final box = await Hive.openBox(kSettingsBoxName);

      final selected = box.get(SettingsKeys.selectedClass) as String? ?? '';
      expect(selected, '');
    });

    test('SettingsKeys.notificationsEnabled matches expected string', () {
      expect(SettingsKeys.notificationsEnabled, 'notifications_enabled');
    });

    test('SettingsKeys.selectedClass matches expected string', () {
      expect(SettingsKeys.selectedClass, 'selected_class');
    });
  });

  // -----------------------------------------------------------------------
  // Full background data flow simulation
  // -----------------------------------------------------------------------
  group('Background data flow simulation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flow_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('simulates background callback data reading flow', () async {
      // Set up settings box with enabled + class selection.
      final settingsBox = await Hive.openBox(kSettingsBoxName);
      await settingsBox.put(SettingsKeys.notificationsEnabled, true);
      await settingsBox.put(SettingsKeys.selectedClass, 'D3-2A');

      // Verify enabled check.
      final enabled =
          settingsBox.get(SettingsKeys.notificationsEnabled) as bool? ?? false;
      expect(enabled, true);

      // Verify class selection.
      final selectedClass =
          settingsBox.get(SettingsKeys.selectedClass) as String? ?? '';
      expect(selectedClass, 'D3-2A');

      // Simulate cache setup.
      final cache = OfflineCache();
      await cache.init();

      // Write schedule data to cache.
      await cache.save(CacheKey.schedules, {
        'semester': '2025/2026',
        'classes': [
          {
            'class_name': 'D3-2A',
            'schedule': [
              {
                'day': 'SENIN',
                'sessions': [
                  {
                    'time': '07.00-08.40',
                    'course_code': '25IF2116',
                    'course_name': 'Proyek 3',
                    'type': 'PR',
                    'lecturer_code': 'XX',
                    'lecturer': 'Test',
                    'room': 'D108-Kelas',
                  },
                ],
              },
            ],
          },
        ],
      });

      // Read and parse as the background callback would.
      final schedulePayload = cache.loadJson(CacheKey.schedules);
      expect(schedulePayload, isA<Map<String, dynamic>>());

      final response = SchedulesResponse.fromJson(
        schedulePayload as Map<String, dynamic>,
      );
      final match = response.classes.firstWhere(
        (c) => c.className == selectedClass,
        orElse: () => response.classes.first,
      );
      final classSchedule = match.schedule;

      // Verify the parsed schedule.
      expect(classSchedule, hasLength(1));
      expect(classSchedule.first.day, Day.senin);
      expect(classSchedule.first.sessions, hasLength(1));
      expect(classSchedule.first.sessions.first.courseCode, '25IF2116');
    });

    test('skips scheduling when notifications disabled', () async {
      final settingsBox = await Hive.openBox(kSettingsBoxName);
      await settingsBox.put(SettingsKeys.notificationsEnabled, false);

      final enabled =
          settingsBox.get(SettingsKeys.notificationsEnabled) as bool? ?? false;
      expect(enabled, false);
      // In the real callback, this would return true immediately.
    });

    test('skips class scheduling when selectedClass is empty', () async {
      final settingsBox = await Hive.openBox(kSettingsBoxName);
      await settingsBox.put(SettingsKeys.notificationsEnabled, true);
      await settingsBox.put(SettingsKeys.selectedClass, '');

      final selectedClass =
          settingsBox.get(SettingsKeys.selectedClass) as String? ?? '';
      expect(selectedClass, isEmpty);
      // In the real callback, classSchedule would remain null.
    });

    test('handles missing cache gracefully', () async {
      final cache = OfflineCache();
      await cache.init();

      // No data saved — loadJson returns null.
      final schedulePayload = cache.loadJson(CacheKey.schedules);
      expect(schedulePayload, isNull);

      final calendarPayload = cache.loadJson(CacheKey.calendar);
      expect(calendarPayload, isNull);

      final penggantiPayload = cache.loadJson(CacheKey.pengganti);
      expect(penggantiPayload, isNull);
    });
  });
}
