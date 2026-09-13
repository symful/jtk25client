/// Events feature providers.
///
/// Wraps T8's `eventsProvider` and adds grouped presentation logic.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../data/events_data.dart';

/// Events grouped into "Akan Datang" / "Selesai".
final groupedEventsProvider = FutureProvider<List<EventGroup>>((ref) async {
  final items = await ref.watch(eventsProvider.future);
  return groupEvents(items, DateTime.now());
});
