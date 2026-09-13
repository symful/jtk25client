/// Events feature providers.
///
/// Wraps T8's `eventsProvider` and adds grouped presentation logic.
///
/// UI watches `eventsProvider` directly for loading/error/data
/// (same pattern as schedules). This provider is a thin sync derivation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../data/events_data.dart';

/// Events grouped into "Akan Datang" / "Selesai".
///
/// Derives from [eventsProvider] synchronously. The UI watches
/// [eventsProvider] directly for loading/error/data states.
final groupedEventsProvider = Provider<List<EventGroup>>((ref) {
  final asyncItems = ref.watch(eventsProvider);
  return asyncItems.when(
    loading: () => const <EventGroup>[],
    error: (_, _) => const <EventGroup>[],
    data: (items) => groupEvents(items, DateTime.now()),
  );
});
