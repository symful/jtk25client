/// Rooms feature providers — search, filter, availability matrix.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/room.dart';
import '../../../core/models/schedule.dart';
import '../../../core/providers/providers.dart';
import '../data/rooms_data.dart';

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class _RoomSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

/// Current search query for the room list.
final roomSearchProvider = NotifierProvider<_RoomSearchNotifier, String>(
  _RoomSearchNotifier.new,
);

/// Filtered room list based on the search query.
///
/// Matches against id, name, and type (case-insensitive).
final filteredRoomsProvider = Provider<List<Room>>((ref) {
  final query = ref.watch(roomSearchProvider).toLowerCase();
  final roomsAsync = ref.watch(roomsProvider);

  return roomsAsync.when(
    loading: () => [],
    error: (_, _) => [],
    data: (list) {
      if (query.isEmpty) return list;
      return list.where((r) {
        return r.id.toLowerCase().contains(query) ||
            r.name.toLowerCase().contains(query) ||
            (r.type?.label.toLowerCase().contains(query) ?? false);
      }).toList();
    },
  );
});

// ---------------------------------------------------------------------------
// Occupancy matrix
// ---------------------------------------------------------------------------

/// The full occupancy matrix built from all class schedules.
final occupancyMatrixProvider = Provider<OccupancyMatrix>((ref) {
  final schedulesAsync = ref.watch(schedulesProvider);

  return schedulesAsync.when(
    loading: () => <String, Map<Day, Map<int, List<SessionOccupancy>>>>{},
    error: (_, _) => <String, Map<Day, Map<int, List<SessionOccupancy>>>>{},
    data: (response) => buildOccupancyMatrix(response.classes),
  );
});

// ---------------------------------------------------------------------------
// Matrix filters
// ---------------------------------------------------------------------------

/// Matrix filter mode: show all, or filter to a specific day/slot.
enum MatrixFilterMode { all, availableNow, daySlot }

class _MatrixFilterNotifier extends Notifier<MatrixFilterMode> {
  @override
  MatrixFilterMode build() => MatrixFilterMode.all;

  void setMode(MatrixFilterMode mode) => state = mode;
}

/// Current matrix filter mode.
final matrixFilterModeProvider =
    NotifierProvider<_MatrixFilterNotifier, MatrixFilterMode>(
      _MatrixFilterNotifier.new,
    );

/// Whether the "Tersedia sekarang" toggle is active.
final showAvailableNowProvider = Provider<bool>((ref) {
  return ref.watch(matrixFilterModeProvider) == MatrixFilterMode.availableNow;
});

/// Available rooms count summary text.
final availableNowSummaryProvider = Provider<String>((ref) {
  final matrix = ref.watch(occupancyMatrixProvider);
  final roomsAsync = ref.watch(roomsProvider);

  return roomsAsync.when(
    loading: () => 'Memuat...',
    error: (_, _) => 'Gagal memuat',
    data: (rooms) {
      final now = DateTime.now();
      final count = countAvailableRooms(matrix, rooms: rooms, now: now);
      return '$count dari ${rooms.length} ruangan kosong sekarang';
    },
  );
});

// ---------------------------------------------------------------------------
// Room detail
// ---------------------------------------------------------------------------

/// All sessions that use a specific room.
final roomSessionsProvider = Provider.family<List<RoomSession>, String>((
  ref,
  roomId,
) {
  final schedulesAsync = ref.watch(schedulesProvider);

  return schedulesAsync.when(
    loading: () => [],
    error: (_, _) => [],
    data: (response) => findRoomSessions(roomId, response.classes),
  );
});

/// Look up a Room by ID.
final roomByIdProvider = Provider.family<Room?, String>((ref, id) {
  final roomsAsync = ref.watch(roomsProvider);

  return roomsAsync.when(
    loading: () => null,
    error: (_, _) => null,
    data: (list) {
      for (final r in list) {
        if (r.id == id) return r;
      }
      return null;
    },
  );
});
