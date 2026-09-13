import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/app.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('jtk25_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(kSettingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('App renders landing page', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Jtk25App()));
    await tester.pumpAndSettle();

    expect(find.text('JTK25'), findsWidgets);
  });
}
