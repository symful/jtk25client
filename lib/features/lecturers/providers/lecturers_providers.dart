/// Lecturers feature providers — search, filter, and detail computation.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/dosen.dart';
import '../../../core/providers/providers.dart';
import '../data/lecturers_data.dart';

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class _DosenSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

/// Current search query for the dosen list.
final dosenSearchProvider = NotifierProvider<_DosenSearchNotifier, String>(
  _DosenSearchNotifier.new,
);

/// Filtered dosen list based on the search query.
///
/// Matches against code and name (case-insensitive).
final filteredDosenProvider = Provider<List<Dosen>>((ref) {
  final query = ref.watch(dosenSearchProvider).toLowerCase();
  final dosenAsync = ref.watch(dosenProvider);

  return dosenAsync.when(
    loading: () => [],
    error: (_, _) => [],
    data: (list) {
      if (query.isEmpty) return list;
      return list.where((d) {
        return d.code.toLowerCase().contains(query) ||
            d.name.toLowerCase().contains(query);
      }).toList();
    },
  );
});

// ---------------------------------------------------------------------------
// Detail: Mengajarkan sessions for a specific dosen
// ---------------------------------------------------------------------------

/// Compute all sessions taught by [lecturerCode] across all classes.
///
/// Returns a [DosenDetail] with the dosen info and their teaching schedule.
final dosenDetailProvider = Provider.family<List<DosenSession>, String>((
  ref,
  lecturerCode,
) {
  final schedulesAsync = ref.watch(schedulesProvider);

  return schedulesAsync.when(
    loading: () => [],
    error: (_, _) => [],
    data: (response) => computeDosenSessions(lecturerCode, response.classes),
  );
});

/// Look up a [Dosen] by code from the dosen list.
final dosenByCodeProvider = Provider.family<Dosen?, String>((ref, code) {
  final dosenAsync = ref.watch(dosenProvider);

  return dosenAsync.when(
    loading: () => null,
    error: (_, _) => null,
    data: (list) {
      for (final d in list) {
        if (d.code == code) return d;
      }
      return null;
    },
  );
});
