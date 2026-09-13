import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/workmanager_callback.dart';
import 'features/settings/data/settings_data.dart';

/// Global scaffold messenger key for web Snackbar fallback.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline caching
  await Hive.initFlutter();

  // Open settings box for class selection persistence.
  await Hive.openBox(kSettingsBoxName);

  // Initialize timezone database with Asia/Jakarta
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // Register WorkManager callbacks for Android background polling.
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    kDataPollTask,
    kDataPollTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  // Initialize notification service and wire up web Snackbar fallback.
  NotificationService.scaffoldMessengerKey = scaffoldMessengerKey;
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: Jtk25App()));
}
