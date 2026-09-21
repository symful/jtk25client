/// Calendar feature providers.
///
/// Wraps T8's `calendarProvider` and adds grouped presentation logic.
///
/// UI watches `calendarProvider` directly for loading/error/data
/// (same pattern as schedules). This provider is a thin sync derivation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/pengganti.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/wib_now.dart';
import '../../schedule/providers/schedule_providers.dart';
import '../data/calendar_data.dart';

/// Calendar items grouped into "Akan Datang" / "Selesai".
///
/// Derives from [calendarProvider] synchronously. The UI watches
/// [calendarProvider] directly for loading/error/data states.
final groupedCalendarProvider = Provider<List<CalendarGroup>>((ref) {
  final asyncItems = ref.watch(calendarProvider);
  return asyncItems.when(
    loading: () => const <CalendarGroup>[],
    error: (_, _) => const <CalendarGroup>[],
    data: (items) => groupEvents(items, wibNow),
  );
});

/// Calendar items grouped by month with upcoming/past separation.
///
/// Combines events from [calendarProvider] with pengganti from
/// [penggantiProvider], filtered by [viewedClassProvider].
final monthGroupedCalendarProvider = Provider<List<CalendarMonthGroup>>((ref) {
  final asyncEvents = ref.watch(calendarProvider);
  final asyncPengganti = ref.watch(penggantiProvider);
  final classCode = ref.watch(viewedClassProvider);

  return asyncEvents.when(
    loading: () => const <CalendarMonthGroup>[],
    error: (_, _) => const <CalendarMonthGroup>[],
    data: (events) {
      final pengganti = asyncPengganti.when(
        loading: () => <PenggantiEntry>[],
        error: (_, _) => <PenggantiEntry>[],
        data: (entries) => entries,
      );
      return groupByMonth(
        events: events,
        penggantiEntries: pengganti,
        classCode: classCode,
        wibNow: wibNow,
      );
    },
  );
});
