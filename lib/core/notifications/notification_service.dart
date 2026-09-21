/// Android notification service for JTK25.
///
/// flutter_local_notifications for foreground FCM display,
/// zonedSchedule for class/calendar/pengganti reminders.
/// FCM push drives data refresh.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart' show GlobalKey, ScaffoldMessengerState;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:hive_ce/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule.dart';
import '../models/calendar.dart';
import '../models/pengganti.dart';
import '../utils/time_slot.dart';
import '../../features/settings/data/settings_data.dart';

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
  bool _initialized = false;

  /// The underlying flutter_local_notifications plugin instance.
  ///
  /// Exposed for FCM service to display foreground messages.
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Scaffold messenger key for web Snackbar fallback.
  ///
  /// Set this from the app's root widget to enable in-app notifications
  /// on web when the browser Notification API is unavailable.
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  // -------------------------------------------------------------------------
  // Initialization
  // -------------------------------------------------------------------------

  /// Initialize the notification service for Android.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
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
    int daysAhead = 7,
  }) async {
    final now = DateTime.now();
    final scheduledKeys = <String>{};
    var alarmId = 1;

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
                '${firstSession.courseName} (${firstSession.type.label}) — ${slot.start} di ${firstSession.room}',
            scheduledTime: scheduledTime,
          );
        }
      }
    }
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

    if (Platform.isAndroid) {
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

  Future<void> scheduleCalendarReminders({
    required List<JtkCalendar> events,
    int daysAhead = 7,
  }) async {
    final now = DateTime.now();
    final box = Hive.box(kSettingsBoxName);
    final scheduledKeys = <String>{};
    var alarmId = 1000;

    for (final event in events) {
      final eventDate = DateTime.tryParse(event.date);
      if (eventDate == null) continue;
      if (eventDate.isBefore(now)) continue;
      if (eventDate.difference(now).inDays > daysAhead) continue;

      final scheduledTime = eventDate.subtract(const Duration(minutes: 30));
      if (scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
        final key = 'cal_${event.id}';
        if (scheduledKeys.contains(key)) continue;
        scheduledKeys.add(key);

        await _scheduleReminder(
          id: alarmId++,
          title: 'Acara segera dimulai',
          body: '${event.title} — ${event.location ?? "Lihat detail"}',
          scheduledTime: tz.TZDateTime(
            tz.local,
            scheduledTime.year,
            scheduledTime.month,
            scheduledTime.day,
            scheduledTime.hour,
            scheduledTime.minute,
          ),
        );
      }
    }
    await box.put('notification_scheduled_calendar', scheduledKeys.toList());
  }

  Future<void> schedulePenggantiReminders({
    required List<PenggantiEntry> entries,
    int daysAhead = 7,
  }) async {
    final now = DateTime.now();
    final box = Hive.box(kSettingsBoxName);
    final scheduledKeys = <String>{};
    var alarmId = 2000;

    for (final entry in entries) {
      final entryDate = DateTime.tryParse(entry.date);
      if (entryDate == null) continue;
      if (entryDate.isBefore(now)) continue;
      if (entryDate.difference(now).inDays > daysAhead) continue;
      if (entry.kind == PenggantiKind.info) continue;

      for (final session in entry.sessions) {
        final slot = TimeSlot.parse(session.time);
        if (slot == null) continue;

        final scheduledTime = tz.TZDateTime(
          tz.local,
          entryDate.year,
          entryDate.month,
          entryDate.day,
          slot.start.hour,
          slot.start.minute,
        ).subtract(const Duration(minutes: 15));

        if (scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
          final key = 'peng_${entry.id}_${slot.start}';
          if (scheduledKeys.contains(key)) continue;
          scheduledKeys.add(key);

          await _scheduleReminder(
            id: alarmId++,
            title: 'Kelas pengganti segera',
            body:
                '${session.courseName} (${session.type.label}) — ${slot.start} di ${session.room}',
            scheduledTime: scheduledTime,
          );
        }
      }
    }
    await box.put('notification_scheduled_pengganti', scheduledKeys.toList());
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  // -------------------------------------------------------------------------
  // Permission management
  // -------------------------------------------------------------------------

  /// Request notification permission. Returns `true` if granted.
  Future<bool> requestPermission() async {
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
    return enabled ? 'Aktif' : 'Diblokir — atur di pengaturan HP';
  }
}
