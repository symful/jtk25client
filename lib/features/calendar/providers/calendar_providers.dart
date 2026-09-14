/// Calendar feature providers.
///
/// Wraps T8's `calendarProvider` and adds grouped presentation logic.
///
/// UI watches `calendarProvider` directly for loading/error/data
/// (same pattern as schedules). This provider is a thin sync derivation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
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
    data: (items) => groupEvents(items, DateTime.now()),
  );
});
