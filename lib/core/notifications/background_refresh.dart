/// Background refresh for Android — workmanager periodic task.
///
/// Runs in a SEPARATE background isolate where the main app's
/// ProviderContainer does NOT exist. Self-sufficient: initializes
/// Hive via Hive.initFlutter(), reads cached schedule data from
/// OfflineCache/Hive boxes, calls NotificationService scheduling
/// directly. NO FCM, NO ProviderContainer, NO UI.
///
/// Server cron push is the authoritative source for notification delivery.
/// This background task is best-effort: it re-schedules local reminders
/// from cached data so they stay fresh even when the app isn't running.
library;

import 'dart:io' show Platform;

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../cache/offline_cache.dart';
import '../models/calendar.dart';
import '../models/pengganti.dart';
import '../models/schedule.dart';
import '../utils/debug_log.dart';
import '../../features/settings/data/settings_data.dart';
import 'notification_service.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// How often the background refresh task runs.
///
/// Server cron is the authoritative source for notification delivery.
/// This task is best-effort: it re-schedules local reminders from
/// cached data so they stay fresh even when the app isn't running.
const Duration kBackgroundRefreshInterval = Duration(hours: 6);

/// Unique name for the periodic workmanager task.
///
/// Used as the [Workmanager.registerPeriodicTask] uniqueName and
/// must remain stable across app updates so the OS replaces the
/// previous registration.
const String kBackgroundRefreshUniqueName = 'jtk25-reminder-refresh';

/// Task name passed to the [Workmanager.executeTask] callback.
const String kBackgroundRefreshTaskName = 'reminderRefresh';

// ---------------------------------------------------------------------------
// Shared reschedule helper
// ---------------------------------------------------------------------------

/// Schedule reminders from explicit data — single implementation
/// shared by both main.dart's startup path and the workmanager
/// background callback.
///
/// [classSchedule] may be null if the class data couldn't be read.
/// [selectedClass] is the persisted class code; empty string means skip.
Future<void> rescheduleRemindersFromData({
  List<DaySchedule>? classSchedule,
  required String selectedClass,
  required List<JtkCalendar> calendarEvents,
  required List<PenggantiEntry> penggantiEntries,
}) async {
  final notif = NotificationService.instance;

  // Single cancel point — wipes stale alarms before the fresh pass.
  await notif.cancelAllReminders();

  // Class reminders
  if (selectedClass.isNotEmpty && classSchedule != null) {
    try {
      await notif.scheduleClassReminders(
        schedule: classSchedule,
        classCode: selectedClass,
      );
    } catch (e) {
      debugLog('[Notif] class reschedule failed: $e');
    }
  }

  // Calendar reminders
  try {
    if (calendarEvents.isNotEmpty) {
      await notif.scheduleCalendarReminders(events: calendarEvents);
    }
  } catch (e) {
    debugLog('[Notif] calendar reschedule failed: $e');
  }

  // Pengganti reminders
  try {
    if (penggantiEntries.isNotEmpty) {
      await notif.schedulePenggantiReminders(entries: penggantiEntries);
    }
  } catch (e) {
    debugLog('[Notif] pengganti reschedule failed: $e');
  }
}

// ---------------------------------------------------------------------------
// Workmanager entry-point
// ---------------------------------------------------------------------------

/// Workmanager entry-point — runs in a SEPARATE background isolate.
///
/// Self-sufficient: initializes Hive, reads cached data from
/// OfflineCache boxes, calls NotificationService directly.
/// NO ProviderContainer, NO FCM, NO UI.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (!Platform.isAndroid) return true;

    debugLog('[WorkManager] background task started: $task');

    try {
      // Initialize Hive for the background isolate.
      // Uses Hive.initFlutter() which calls path_provider internally
      // to find the same directory the main isolate uses.
      await Hive.initFlutter();
      await Hive.openBox(kSettingsBoxName);

      // Initialize timezone database for Asia/Jakarta scheduling.
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      // Check if notifications are enabled.
      final box = Hive.box(kSettingsBoxName);
      final enabled =
          box.get(SettingsKeys.notificationsEnabled) as bool? ?? false;
      if (!enabled) {
        debugLog('[WorkManager] notifications disabled — skipping');
        return true;
      }

      // Read selected class code.
      final selectedClass =
          box.get(SettingsKeys.selectedClass) as String? ?? '';

      // Read cached data from OfflineCache boxes.
      final cache = OfflineCache();
      await cache.init();

      // Parse schedules cache.
      List<DaySchedule>? classSchedule;
      final schedulePayload = cache.loadJson(CacheKey.schedules);
      if (schedulePayload is Map<String, dynamic> && selectedClass.isNotEmpty) {
        try {
          final response = SchedulesResponse.fromJson(schedulePayload);
          final match = response.classes.firstWhere(
            (c) => c.className == selectedClass,
            orElse: () => response.classes.first,
          );
          classSchedule = match.schedule;
        } catch (e) {
          debugLog('[WorkManager] schedule cache decode failed: $e');
        }
      }

      // Parse calendar cache.
      var calendarEvents = <JtkCalendar>[];
      final calendarPayload = cache.loadJson(CacheKey.calendar);
      if (calendarPayload is Map<String, dynamic>) {
        try {
          final items = calendarPayload['data'];
          if (items != null) {
            calendarEvents = JtkCalendar.listFromJson(items);
          }
        } catch (e) {
          debugLog('[WorkManager] calendar cache decode failed: $e');
        }
      }

      // Parse pengganti cache.
      var penggantiEntries = <PenggantiEntry>[];
      final penggantiPayload = cache.loadJson(CacheKey.pengganti);
      if (penggantiPayload is Map<String, dynamic>) {
        try {
          final items = penggantiPayload['data'];
          if (items != null) {
            penggantiEntries = PenggantiEntry.listFromJson(items);
          }
        } catch (e) {
          debugLog('[WorkManager] pengganti cache decode failed: $e');
        }
      }

      // Initialize notification service for the background isolate.
      await NotificationService.instance.init();

      // Delegate to shared helper for actual scheduling.
      await rescheduleRemindersFromData(
        classSchedule: classSchedule,
        selectedClass: selectedClass,
        calendarEvents: calendarEvents,
        penggantiEntries: penggantiEntries,
      );

      debugLog('[WorkManager] background reschedule complete');
      return true;
    } catch (e) {
      debugLog('[WorkManager] background task failed: $e');
      return false;
    }
  });
}
