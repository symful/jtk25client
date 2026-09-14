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
import 'core/notifications/notification_service.dart';
import 'core/providers/providers.dart';
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

  runApp(
    UncontrolledProviderScope(container: _container, child: const Jtk25App()),
  );
}

Future<void> _rescheduleReminders() async {
  final notif = NotificationService.instance;
  await notif.cancelAllReminders();

  try {
    final schedulesAsync = _container.read(schedulesProvider);
    final schedules = schedulesAsync.asData?.value;
    final selectedClass = _container.read(selectedClassProvider);
    if (schedules != null && selectedClass.isNotEmpty) {
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
  } catch (_) {}

  try {
    final calendarAsync = _container.read(calendarProvider);
    final calendar = calendarAsync.asData?.value;
    if (calendar != null && calendar.isNotEmpty) {
      await notif.scheduleCalendarReminders(events: calendar);
    }
  } catch (_) {}

  try {
    final penggantiAsync = _container.read(penggantiProvider);
    final pengganti = penggantiAsync.asData?.value;
    if (pengganti != null && pengganti.isNotEmpty) {
      await notif.schedulePenggantiReminders(entries: pengganti);
    }
  } catch (_) {}
}
