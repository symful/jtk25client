import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/cache/offline_cache.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/providers.dart';
import 'core/utils/debug_log.dart';
import 'core/utils/live_schedule_tracker.dart';
import 'features/announcements/data/announcements_data.dart';
import 'features/schedule/providers/schedule_providers.dart';
import 'features/settings/data/settings_data.dart';
import 'firebase_options.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

late final ProviderContainer _container;
final liveTracker = LiveScheduleTracker();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Hive.initFlutter();
  await Hive.openBox(kSettingsBoxName);

  await AnnouncementsSeen().init();
  await initializeDateFormatting('id_ID');
  await OfflineCache().init();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  _container = ProviderContainer();

  // Wire the reschedule callback into the notification enabled notifier
  // so toggle(true) triggers a reschedule, and T4's workmanager can reuse it.
  _container
      .read(notificationEnabledProvider.notifier)
      .setRescheduleCallback(_rescheduleReminders);

  FcmService.onScheduleUpdate = () =>
      _container.read(scheduleTriggerProvider.notifier).increment();
  FcmService.onCalendarUpdate = () =>
      _container.read(calendarTriggerProvider.notifier).increment();
  FcmService.onPenggantiUpdate = () =>
      _container.read(penggantiTriggerProvider.notifier).increment();
  FcmService.onRescheduleReminders = () => _rescheduleReminders();

  NotificationService.scaffoldMessengerKey = scaffoldMessengerKey;
  await NotificationService.instance.init();

  await FcmService.instance.init(
    localNotifications: NotificationService.instance.plugin,
  );

  // Startup reschedule: schedule reminders immediately if notifications
  // are enabled, so the user gets reminders without needing an FCM message.
  if (_container.read(notificationEnabledProvider)) {
    _rescheduleReminders();
  }

  runApp(
    UncontrolledProviderScope(container: _container, child: const Jtk25App()),
  );
}

/// Reschedule all local reminders from current provider data.
///
/// Called at startup (fire-and-forget) and on FCM data-message arrival.
/// Also exposed as the workmanager reschedule entry point for T4.
Future<void> _rescheduleReminders() async {
  final notif = NotificationService.instance;

  // Single cancel point — wipes stale alarms before the fresh pass.
  await notif.cancelAllReminders();

  // Class reminders
  try {
    final schedules = await _container
        .read(schedulesProvider.future)
        .timeout(const Duration(seconds: 10));
    final selectedClass = _container.read(selectedClassProvider);
    if (selectedClass.isNotEmpty) {
      final cls = schedules.classes.firstWhere(
        (c) => c.className == selectedClass,
        orElse: () => schedules.classes.first,
      );
      await notif.scheduleClassReminders(
        schedule: cls.schedule,
        classCode: selectedClass,
      );
      liveTracker.start(schedules.classes);
    }
  } catch (e) {
    debugLog('[Notif] class reschedule failed: $e');
  }

  // Calendar reminders
  try {
    final calendar = await _container
        .read(calendarProvider.future)
        .timeout(const Duration(seconds: 10));
    if (calendar.isNotEmpty) {
      await notif.scheduleCalendarReminders(events: calendar);
    }
  } catch (e) {
    debugLog('[Notif] calendar reschedule failed: $e');
  }

  // Pengganti reminders
  try {
    final pengganti = await _container
        .read(penggantiProvider.future)
        .timeout(const Duration(seconds: 10));
    if (pengganti.isNotEmpty) {
      await notif.schedulePenggantiReminders(entries: pengganti);
    }
  } catch (e) {
    debugLog('[Notif] pengganti reschedule failed: $e');
  }
}
