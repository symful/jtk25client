import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/room.dart';
import 'package:jtk25_client/core/theme/theme.dart';
import 'package:jtk25_client/core/ui/mode_badge.dart';

/// Relative luminance per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// Contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Pump [child] inside a MaterialApp using the given theme.
Future<void> pumpIn(
  WidgetTester tester,
  ThemeData theme,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  // Every hue used as a status colour across the app.
  const hues = <String, Color>{
    'blue': Colors.blue,
    'green': Colors.green,
    'red': Colors.red,
    'grey': Colors.grey,
    'orange': Colors.orange,
    'amber': Colors.amber,
    'purple': Colors.purple,
    'teal': Colors.teal,
  };

  group('StatusColors contrast', () {
    for (final entry in hues.entries) {
      for (final dark in [false, true]) {
        for (final tone in StatusTone.values) {
          testWidgets(
            '${entry.key} ${tone.name} ${dark ? "dark" : "light"} readable',
            (tester) async {
              final theme =
                  dark ? buildJtk25DarkTheme() : buildJtk25Theme();
              late StatusColors result;

              await pumpIn(
                tester,
                theme,
                Builder(
                  builder: (context) {
                    result = statusColors(context, entry.value, tone);
                    return const SizedBox.shrink();
                  },
                ),
              );

              final ratio = _contrast(result.foreground, result.background);

              // WCAG AA for normal text is 4.5:1.
              expect(
                ratio,
                greaterThanOrEqualTo(4.5),
                reason:
                    '${entry.key}/${tone.name}/${dark ? "dark" : "light"} '
                    'contrast was ${ratio.toStringAsFixed(2)}:1 — '
                    'fg ${result.foreground} on bg ${result.background}',
              );
            },
          );
        }
      }
    }
  });

  group('ModeBadge renders in both themes', () {
    for (final dark in [false, true]) {
      testWidgets('online badge builds (${dark ? "dark" : "light"})', (
        tester,
      ) async {
        final theme = dark ? buildJtk25DarkTheme() : buildJtk25Theme();
        await pumpIn(tester, theme, const ModeBadge(isOnline: true));
        expect(find.text('Online'), findsOneWidget);
      });

      testWidgets('offline badge builds (${dark ? "dark" : "light"})', (
        tester,
      ) async {
        final theme = dark ? buildJtk25DarkTheme() : buildJtk25Theme();
        await pumpIn(tester, theme, const ModeBadge(isOnline: false));
        expect(find.text('Offline'), findsOneWidget);
      });
    }
  });

  group('room helpers', () {
    test('online room has its own label and icon', () {
      expect(roomTypeLabel(RoomType.online), 'Online');
      expect(roomTypeIcon(RoomType.online), Icons.cloud_outlined);
      expect(RoomType.online.isPhysical, isFalse);
      expect(RoomType.kelas.isPhysical, isTrue);
      expect(RoomType.lab.isPhysical, isTrue);
    });
  });
}