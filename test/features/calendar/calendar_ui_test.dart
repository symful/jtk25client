import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jtk25_client/core/models/calendar.dart';
import 'package:jtk25_client/core/models/pengganti.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/core/providers/providers.dart';
import 'package:jtk25_client/core/utils/wib_now.dart';
import 'package:jtk25_client/features/calendar/ui/calendar_ui.dart';
import 'package:jtk25_client/features/settings/data/settings_data.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

JtkCalendar _makeEvent({
  required String id,
  required String title,
  required String date,
  required String endDate,
  String? location,
  String? category,
  String? description,
}) {
  return JtkCalendar(
    id: id,
    title: title,
    description: description,
    date: date,
    endDate: endDate,
    location: location,
    category: category,
  );
}

PenggantiEntry _makePengganti({
  required String id,
  required String classCode,
  required String date,
  PenggantiKind kind = PenggantiKind.replace,
  String? note,
  List<Session> sessions = const [],
}) {
  return PenggantiEntry(
    id: id,
    classCode: classCode,
    date: date,
    kind: kind,
    note: note,
    sessions: sessions,
  );
}

String _wibDate([int daysOffset = 0]) {
  final d = wibNow.add(Duration(days: daysOffset));
  return DateFormat('yyyy-MM-dd').format(d);
}

String _wibDateTime([int daysOffset = 0, int hour = 9]) {
  final d = wibNow.add(Duration(days: daysOffset));
  return '${DateFormat('yyyy-MM-dd').format(d)}T${hour.toString().padLeft(2, '0')}:00:00';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  const testClassName = 'D3-2A';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id');
    tempDir = await Directory.systemTemp.createTemp('jtk25_calendar_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(kSettingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> buildCalendarPage(
    WidgetTester tester, {
    required List<JtkCalendar> events,
    List<PenggantiEntry> pengganti = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarProvider.overrideWithValue(AsyncData(events)),
          penggantiProvider.overrideWithValue(AsyncData(pengganti)),
        ],
        child: const MaterialApp(home: CalendarPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tap the SegmentedButton's "Kalender" segment.
  Future<void> tapKalenderSegment(WidgetTester tester) async {
    final segmented = find.byType(SegmentedButton<int>);
    final kalenderText = find.descendant(
      of: segmented,
      matching: find.text('Kalender'),
    );
    await tester.tap(kalenderText);
    await tester.pumpAndSettle();
  }

  group('SegmentedButton tabs', () {
    testWidgets('defaults to Daftar (list) view', (tester) async {
      await buildCalendarPage(tester, events: []);
      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Tidak ada acara'), findsOneWidget);
    });

    testWidgets('switching to Kalender shows grid view', (tester) async {
      await buildCalendarPage(tester, events: []);
      await tapKalenderSegment(tester);
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Sel'), findsOneWidget);
    });
  });

  group('Grouped month list', () {
    testWidgets('renders month headers and events', (tester) async {
      final now = wibNow;
      final events = [
        _makeEvent(
          id: '1',
          title: 'Event bulan ini',
          date: _wibDateTime(1),
          endDate: _wibDateTime(1),
          category: 'Kampus',
        ),
        _makeEvent(
          id: '2',
          title: 'Event bulan depan',
          date: _wibDateTime(32),
          endDate: _wibDateTime(32),
        ),
      ];

      await buildCalendarPage(tester, events: events);

      final thisMonthLabel = DateFormat(
        'MMMM yyyy',
        'id',
      ).format(DateTime(now.year, now.month));
      final nextMonth = DateTime(now.year, now.month + 1);
      final nextMonthLabel = DateFormat('MMMM yyyy', 'id').format(nextMonth);

      expect(find.text(thisMonthLabel), findsOneWidget);
      expect(find.text(nextMonthLabel), findsOneWidget);
      expect(find.text('Event bulan ini'), findsOneWidget);
      expect(find.text('Event bulan depan'), findsOneWidget);
    });

    testWidgets('upcoming before past with opacity distinction', (
      tester,
    ) async {
      final events = [
        _makeEvent(
          id: 'past',
          title: 'Event lalu',
          date: _wibDateTime(-5),
          endDate: _wibDateTime(-5),
        ),
        _makeEvent(
          id: 'upcoming',
          title: 'Event depan',
          date: _wibDateTime(5),
          endDate: _wibDateTime(5),
        ),
      ];

      await buildCalendarPage(tester, events: events);

      expect(find.text('Event depan'), findsOneWidget);
      expect(find.text('Event lalu'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      // Upcoming = full opacity, past = 0.5 opacity.
      final upcomingOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Event depan'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(upcomingOpacity.opacity, 1.0);

      final pastOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Event lalu'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(pastOpacity.opacity, 0.5);
    });
  });

  group('Multi-day event badge', () {
    testWidgets('multi-day event shows s/d badge', (tester) async {
      final events = [
        _makeEvent(
          id: '1',
          title: 'Konferensi',
          date: _wibDateTime(1),
          endDate: _wibDateTime(3),
        ),
      ];

      await buildCalendarPage(tester, events: events);
      expect(find.textContaining('s/d'), findsOneWidget);
      expect(find.text('Konferensi'), findsOneWidget);
    });

    testWidgets('single-day event does NOT show s/d badge', (tester) async {
      final events = [
        _makeEvent(
          id: '1',
          title: 'Kuliah',
          date: _wibDateTime(1),
          endDate: _wibDateTime(1),
        ),
      ];

      await buildCalendarPage(tester, events: events);
      expect(find.textContaining('s/d'), findsNothing);
    });
  });

  group('Category filter chips', () {
    testWidgets('filters events by category', (tester) async {
      final events = [
        _makeEvent(
          id: '1',
          title: 'Kuliah Pagi',
          date: _wibDateTime(1),
          endDate: _wibDateTime(1),
          category: 'Akademik',
        ),
        _makeEvent(
          id: '2',
          title: 'Festival Seni',
          date: _wibDateTime(2),
          endDate: _wibDateTime(2),
          category: 'Seni',
        ),
        _makeEvent(
          id: '3',
          title: 'Upacara',
          date: _wibDateTime(3),
          endDate: _wibDateTime(3),
        ),
      ];

      await buildCalendarPage(tester, events: events);

      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Kuliah Pagi'), findsOneWidget);
      expect(find.text('Festival Seni'), findsOneWidget);
      expect(find.text('Upacara'), findsOneWidget);

      // Tap "Seni" FilterChip.
      final seniChip = find.byWidgetPredicate(
        (w) =>
            w is FilterChip &&
            w.label is Text &&
            (w.label as Text).data == 'Seni',
      );
      await tester.tap(seniChip);
      await tester.pumpAndSettle();

      expect(find.text('Festival Seni'), findsOneWidget);
      expect(find.text('Kuliah Pagi'), findsNothing);
      expect(find.text('Upacara'), findsNothing);
    });
  });

  group('Jump to today button', () {
    testWidgets('AppBar has today icon button', (tester) async {
      await buildCalendarPage(tester, events: []);
      expect(find.byIcon(Icons.today), findsOneWidget);
    });
  });

  group('Pengganti integration', () {
    testWidgets('pengganti entries appear in list', (tester) async {
      final pengganti = [
        _makePengganti(
          id: 'p1',
          classCode: testClassName,
          date: _wibDate(2),
          kind: PenggantiKind.replace,
          note: 'Ganti ruangan',
        ),
      ];

      await buildCalendarPage(tester, events: [], pengganti: pengganti);
      expect(find.text('Ganti ruangan'), findsOneWidget);
    });

    testWidgets('pengganti for other classes are filtered out', (tester) async {
      final pengganti = [
        _makePengganti(
          id: 'p1',
          classCode: 'D4-2B',
          date: _wibDate(2),
          kind: PenggantiKind.replace,
          note: 'Other class',
        ),
      ];

      await buildCalendarPage(tester, events: [], pengganti: pengganti);
      expect(find.text('Other class'), findsNothing);
    });
  });

  group('Empty and error states', () {
    testWidgets('loading shows spinner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarProvider.overrideWithValue(const AsyncLoading()),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error shows retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarProvider.overrideWithValue(
              AsyncError('test error', StackTrace.empty),
            ),
            penggantiProvider.overrideWithValue(const AsyncData([])),
          ],
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat kalender'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('Grid view', () {
    testWidgets('grid renders weekday headers after switching', (tester) async {
      await buildCalendarPage(tester, events: []);
      await tapKalenderSegment(tester);
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Jum'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);
    });
  });
}
