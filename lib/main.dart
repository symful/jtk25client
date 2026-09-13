import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'features/settings/data/settings_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline caching
  await Hive.initFlutter();

  // Open settings box for class selection persistence.
  await Hive.openBox(kSettingsBoxName);

  // Initialize timezone database with Asia/Jakarta
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // TODO: Register workmanager callbacks (T13)

  runApp(const ProviderScope(child: Jtk25App()));
}
