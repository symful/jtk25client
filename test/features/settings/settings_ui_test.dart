/// Tests for settings UI — verifies class selector, single notification
/// toggle, and absence of old notification jargon.
///
/// All strings in Bahasa Indonesia.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';
import 'package:jtk25_client/features/settings/ui/settings_ui.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('jtk25_settings_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(kSettingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget buildTestWidget() {
    return ProviderScope(child: MaterialApp(home: const SettingsPage()));
  }

  group('SettingsPage', () {
    testWidgets('renders app bar with "Pengaturan"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan'), findsOneWidget);
    });

    testWidgets('shows class selector with all class codes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // "Kelas" section header.
      expect(find.text('Kelas'), findsOneWidget);

      // All class codes as radio list tiles.
      for (final code in kAllClassCodes) {
        expect(find.text(code), findsOneWidget);
      }
    });

    testWidgets('shows single notification toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // The "Pemberitahuan" section header.
      expect(find.text('Pemberitahuan'), findsWidgets);

      // SwitchListTile toggle exists.
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('does NOT have "Lihat Detail" button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Lihat Detail'), findsNothing);
    });

    testWidgets('does NOT have duplicate notification sections', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Only one SwitchListTile (the single toggle).
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('does NOT show forbidden notification jargon', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // These terms must NOT appear in the UI.
      expect(find.textContaining('Push'), findsNothing);
      expect(find.textContaining('Topik'), findsNothing);
      expect(find.textContaining('Langganan'), findsNothing);
      expect(find.textContaining('Token'), findsNothing);
      expect(find.textContaining('FCM'), findsNothing);
    });

    testWidgets('shows editor data entry', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll to make the editor section visible.
      await tester.scrollUntilVisible(
        find.text('Editor Data'),
        100,
        scrollable: find.byType(Scrollable).last,
      );

      // Editor Data ListTile.
      expect(find.text('Editor Data'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}
