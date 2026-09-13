/// Top-level WorkManager callback for Android background data polling.
///
/// This function MUST be a top-level function (not inside a class) and
/// annotated with `@pragma("vm:entry-point")` so the Dart VM can invoke it
/// from a background isolate.
///
/// WorkManager runs this periodically (15 min) to check for data updates
/// even when the app is killed. It initializes Hive and timezone in the
/// background isolate, fetches `/api/v1/meta`, and shows a local notification
/// if the dataVersion has changed.
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../api/jtk_api.dart';
import '../utils/debug_log.dart';
import 'notification_service.dart';
import '../../features/settings/data/settings_data.dart';

/// Hive key for last-seen data version (mirrors notification_service.dart).
const String _kLastDataVersionKey = 'notification_last_data_version';

/// WorkManager task name for the periodic data poll.
const String kDataPollTask = 'jtk25DataPoll';

/// Top-level callback dispatcher — entry point for WorkManager background tasks.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugLog('[WorkManager] task started: $task');

    try {
      // Initialize Hive in the background isolate.
      await Hive.initFlutter();
      await Hive.openBox(kSettingsBoxName);

      // Initialize timezone database.
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      // Fetch meta and compare dataVersion.
      final api = JtkApi();
      final box = Hive.box(kSettingsBoxName);
      final lastVersion = box.get(_kLastDataVersionKey) as String? ?? '';

      final meta = await api.meta();
      api.close();

      if (meta.dataVersion.isNotEmpty &&
          meta.dataVersion != lastVersion &&
          lastVersion.isNotEmpty) {
        // Data has changed — show a local notification.
        await _showBackgroundNotification(
          'Pembaruan Tersedia',
          'Data jadwal telah diperbarui.',
        );
        await box.put(_kLastDataVersionKey, meta.dataVersion);
        debugLog(
          '[WorkManager] data updated $lastVersion → ${meta.dataVersion}',
        );
      } else {
        debugLog('[WorkManager] no data change (${meta.dataVersion})');
      }

      return true; // Task succeeded.
    } catch (e) {
      debugLog('[WorkManager] task failed: $e');
      return false; // Will retry with backoff.
    }
  });
}

/// Show a notification from the background isolate.
///
/// Uses flutter_local_notifications directly (no Riverpod, no app state).
Future<void> _showBackgroundNotification(String title, String body) async {
  final plugin = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(settings: initSettings);

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      kNotificationChannelId,
      kNotificationChannelName,
      channelDescription: kNotificationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Use notification ID 0 (same as in-app update notification) so only one
  // update notification shows at a time.
  await plugin.show(
    id: 0,
    title: title,
    body: body,
    notificationDetails: details,
  );
}
