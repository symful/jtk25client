// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jtk25_client/app.dart';

void main() {
  testWidgets('App renders placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Jtk25App()));
    await tester.pumpAndSettle();

    // Verify placeholder text renders
    expect(find.text('Selamat datang di JTK25'), findsOneWidget);
  });
}
