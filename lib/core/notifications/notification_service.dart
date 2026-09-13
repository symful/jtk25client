/// Cross-platform notification service for JTK25.
///
/// - **Android**: WorkManager 15-min periodic poll, flutter_local_notifications,
///   zonedSchedule for class reminders with exact-alarm fallback.
/// - **Windows**: Timer 15-min poll while process alive, flutter_local_notifications,
///   zonedSchedule for class reminders.
/// - **Web**: dart:html Notification API with Snackbar fallback; Timer + visibility poll.
///
/// Dedup: same dataVersion → no repeat; same course-block → one alarm.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show GlobalKey, ScaffoldMessengerState, SnackBar, Text;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:hive_ce/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../api/jtk_api.dart';
import '../models/schedule.dart';
import '../utils/time_slot.dart';
import '../../features/settings/data/settings_data.dart';
import '_web_helper_stub.dart' if (dart.library.html) '_web_helper.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Notification channel ID (Android).
const String kNotificationChannelId = 'jtk25_updates';

/// Notification channel name (Android).
const String kNotificationChannelName = 'Pembaruan Jadwal';

/// Notification channel description.
const String kNotificationChannelDesc =
    'Notifikasi pembaruan data jadwal dan pengingat kelas';

/// Hive key for last-seen data version (dedup).
const String _kLastDataVersionKey = 'notification_last_data_version';

/// Hive key for scheduled alarm dedup keys.
const String _kScheduledAlarmsKey = 'notification_scheduled_alarms';

/// Notification ID reserved for the data-update notification.
const int _kDataUpdateNotifId = 0;

// ---------------------------------------------------------------------------
// NotificationService singleton
// ---------------------------------------------------------------------------

/// Platform-aware notification service.
///
/// Use [NotificationService.instance] to access the singleton.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Timer? _pollTimer;
  bool _initialized = false;

  /// Scaffold messenger key for web Snackbar fallback.
  ///
  /// Set this from the app's root widget to enable in-app notifications
  /// on web when the browser Notification API is unavailable.
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  // -------------------------------------------------------------------------
  // Initialization
  // -------------------------------------------------------------------------

  /// Initialize the notification service for the current platform.
  ///
  /// On Android/Windows, creates the notification channel and initializes
  /// flutter_local_notifications. On web, no initialization is needed.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) return; // No flutter_local_notifications on web.

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android 8+.
    if (!kIsWeb && Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  Future<void> _createNotificationChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotificationChannelId,
          kNotificationChannelName,
          description: kNotificationChannelDesc,
        ),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Could navigate based on response.payload in the future.
  }

  // -------------------------------------------------------------------------
  // Polling
  // -------------------------------------------------------------------------

  /// Start periodic polling every 15 minutes.
  ///
  /// On Android, WorkManager also handles background polling; this in-app
  /// timer covers the foreground case. On Windows, this is the only poller.
  /// On web, visibility-change events are also registered.
  void startPolling() {
    _pollTimer?.cancel();
    // Poll immediately on start.
    unawaited(checkForDataUpdate());
    _pollTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(checkForDataUpdate()),
    );

    // On web, also poll when the page becomes visible again.
    if (kIsWeb) {
      webStartVisibilityListener(() => unawaited(checkForDataUpdate()));
    }
  }

  /// Cancel the periodic poll timer.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // -------------------------------------------------------------------------
  // Data-version check (the core poll logic)
  // -------------------------------------------------------------------------

  /// Poll `/api/v1/meta` and compare [dataVersion] against the Hive-stored
  /// value. Returns `true` if data changed (not first load).
  ///
  /// Dedup: same dataVersion → no notification.
  Future<bool> checkForDataUpdate({JtkApi? api}) async {
    final box = Hive.box(kSettingsBoxName);
    final lastVersion = box.get(_kLastDataVersionKey) as String? ?? '';

    try {
      final client = api ?? JtkApi();
      final meta = await client.meta();

      if (meta.dataVersion.isNotEmpty && meta.dataVersion != lastVersion) {
        // Only notify if this isn't the very first load.
        if (lastVersion.isNotEmpty) {
          await _notifyDataChanged();
        }
        await box.put(_kLastDataVersionKey, meta.dataVersion);
        return lastVersion.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('NotificationService: poll failed: $e');
      return false;
    }
  }

  Future<void> _notifyDataChanged() async {
    if (kIsWeb) {
      // Web: browser Notification or in-app Snackbar fallback.
      if (webNotificationSupported()) {
        webShowNotification(
          'Pembaruan Tersedia',
          'Data jadwal telah diperbarui. Buka untuk melihat perubahan.',
        );
      } else {
        _showInAppSnackbar('Data jadwal telah diperbarui.');
      }
      return;
    }

    // Android / Windows: flutter_local_notifications.
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kNotificationChannelId,
        kNotificationChannelName,
        channelDescription: kNotificationChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: _kDataUpdateNotifId,
      title: 'Pembaruan Tersedia',
      body: 'Data jadwal telah diperbarui.',
      notificationDetails: details,
    );
  }

  void _showInAppSnackbar(String message) {
    scaffoldMessengerKey?.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  // -------------------------------------------------------------------------
  // Class reminders
  // -------------------------------------------------------------------------

  /// Schedule class reminders for the next [daysAhead] days.
  ///
  /// ONE alarm per course-block start (consecutive same-courseCode sessions
  /// merge into one block). Reminders fire 15 minutes before each block
  /// starts, in Asia/Jakarta timezone.
  ///
  /// On web, reminders are a no-op (no service-worker push).
  Future<void> scheduleClassReminders({
    required List<DaySchedule> schedule,
    required String classCode,
    int daysAhead = 2,
  }) async {
    if (kIsWeb) return; // No scheduled notifications on web.

    await cancelAllReminders();

    final now = DateTime.now();
    final box = Hive.box(kSettingsBoxName);
    final scheduledKeys = <String>{};
    var alarmId = 1; // 0 is reserved for data-update notification.

    for (var dayOffset = 0; dayOffset <= daysAhead; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final weekday = targetDate.weekday; // 1=Mon, 7=Sun

      // Find the matching Day enum (index = weekday - 1).
      if (weekday < 1 || weekday > 5) continue; // Mon–Fri only.
      final dayEnum = Day.values[weekday - 1];

      final daySchedule = schedule.firstWhere(
        (d) => d.day == dayEnum,
        orElse: () => DaySchedule(day: dayEnum, sessions: []),
      );

      if (daySchedule.sessions.isEmpty) continue;

      // Group sessions into course blocks (consecutive same-courseCode).
      final blocks = _groupIntoBlocks(daySchedule.sessions);

      for (final block in blocks) {
        if (block.isEmpty) continue;
        final firstSession = block.first;
        final slot = TimeSlot.parse(firstSession.time);
        if (slot == null) continue;

        final key =
            '${dayEnum.name}_${slot.start.toString()}_${firstSession.courseCode}';
        if (scheduledKeys.contains(key)) continue;
        scheduledKeys.add(key);

        // Schedule 15 minutes before the block starts.
        final scheduledTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          slot.start.hour,
          slot.start.minute,
        ).subtract(const Duration(minutes: 15));

        if (scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
          await _scheduleReminder(
            id: alarmId++,
            title: 'Kelas segera dimulai',
            body:
                '${firstSession.courseName} (${firstSession.type.label}) — ${slot.start}',
            scheduledTime: scheduledTime,
          );
        }
      }
    }

    // Persist scheduled keys for dedup across restarts.
    await box.put(_kScheduledAlarmsKey, scheduledKeys.toList());
  }

  /// Group consecutive sessions with the same [courseCode] into blocks.
  List<List<Session>> _groupIntoBlocks(List<Session> sessions) {
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

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kNotificationChannelId,
        kNotificationChannelName,
        channelDescription: kNotificationChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    // Android 12+ exact-alarm fallback.
    var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final canSchedule =
            await androidPlugin.canScheduleExactNotifications() ?? false;
        if (!canSchedule) {
          final granted =
              await androidPlugin.requestExactAlarmsPermission() ?? false;
          if (!granted) {
            scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          }
        }
      }
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: scheduleMode,
    );
  }

  /// Cancel all scheduled notifications (reminders).
  Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  // -------------------------------------------------------------------------
  // Permission management
  // -------------------------------------------------------------------------

  /// Request notification permission. Returns `true` if granted.
  Future<bool> requestPermission() async {
    if (kIsWeb) return webRequestPermission();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Check if notifications are currently enabled/granted.
  Future<bool> isEnabled() async {
    if (kIsWeb) return webNotificationSupported();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    return false;
  }

  /// Human-readable status string in Indonesian.
  Future<String> statusText() async {
    final enabled = await isEnabled();
    return enabled ? 'Aktif' : 'Nonaktif (izin ditolak)';
  }
}
