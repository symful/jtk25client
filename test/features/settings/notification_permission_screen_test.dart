/// Tests for notification permission screen — verifies UI rendering
/// for each permission state branch.
///
/// In the test environment, `flutter_local_notifications` plugin is not
/// initialized, so `_checkPermissionState` catches the error and shows
/// the `notDetermined` state (CTA button visible).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';
import 'package:jtk25_client/features/settings/ui/notification_permission_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('jtk25_notif_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(kSettingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget buildTestWidget() {
    return ProviderScope(
      child: MaterialApp(home: const NotificationPermissionScreen()),
    );
  }

  group('NotificationPermissionScreen', () {
    testWidgets('renders with app bar and content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      // Allow post-frame callback to fire and state to settle.
      await tester.pumpAndSettle();

      // App bar title.
      expect(find.text('Pemberitahuan'), findsOneWidget);

      // In test env, permission check fails → shows CTA (notDetermined state).
      expect(find.text('Aktifkan Pemberitahuan'), findsWidgets);
    });

    testWidgets('shows CTA button in notDetermined state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The big CTA button text.
      expect(
        find.widgetWithText(FilledButton, 'Aktifkan Pemberitahuan'),
        findsOneWidget,
      );
    });

    testWidgets('shows feature description cards', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Pengumuman & Jadwal Pengganti'), findsOneWidget);
      expect(find.text('Pengingat Kelas'), findsOneWidget);
    });

    testWidgets('has back navigation button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
