/// Rooms feature UI — searchable room list, detail, and availability matrix.
///
/// Shows room occupancy across Senin-Jumat with day-chip selection.
/// Supports search, overlap markers, and "Tersedia sekarang" indicator.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/offline_cache.dart';
import '../../../core/models/room.dart';
import '../../../core/models/schedule.dart';
import '../../../core/providers/providers.dart';
import '../../../core/ui/refresh_helpers.dart';
import '../data/rooms_data.dart';
import '../providers/rooms_providers.dart';

// ---------------------------------------------------------------------------
// Rooms list page
// ---------------------------------------------------------------------------

/// Refresh rooms + schedules (for matrix): invalidate providers → await → change detection.
Future<void> _onRefreshRooms(BuildContext context, WidgetRef ref) async {
  await refreshData(
    context,
    ref,
    keys: [CacheKey.rooms, CacheKey.schedules],
    refresh: () async {
      ref.invalidate(roomsProvider);
      ref.invalidate(schedulesProvider);
      await ref.read(roomsProvider.future);
      await ref.read(schedulesProvider.future);
    },
  );
}

/// Full-screen searchable room list with day-specific availability.
///
/// Watches [roomsProvider] and [schedulesProvider] directly for
/// loading/error/data (same pattern as schedule_ui.dart).
class RoomsListPage extends ConsumerWidget {
  const RoomsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruangan'),
        actions: [
          AppRefreshButton(onRefresh: () => _onRefreshRooms(context, ref)),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Gagal memuat ruangan',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (_) {
          // Filtered room list from the sync derivation.
          final filtered = ref.watch(filteredRoomsProvider);
          return Column(
            children: [
              // Day chips.
              const _RoomDayChipsRow(),
              // Search bar.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari ruangan...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(roomSearchProvider.notifier).update(value);
                  },
                ),
              ),
              // Available count summary.
              const _DayAvailableBanner(),
              // Room list.
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _onRefreshRooms(context, ref),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'Tidak ada ruangan ditemukan',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _RoomListTile(room: filtered[index]);
                          },
                        ),
                ),
              ),
              // Matrix button.
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/ruangan/matriks'),
                    icon: const Icon(Icons.grid_on),
                    label: const Text('Matriks Ketersediaan'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day chips row for room availability
// ---------------------------------------------------------------------------

class _RoomDayChipsRow extends ConsumerWidget {
  const _RoomDayChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedRoomDayProvider);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: kWorkdays.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final day = kWorkdays[index];
          return ChoiceChip(
            label: Text(_dayLabel(day)),
            selected: day == selectedDay,
            onSelected: (_) {
              ref.read(selectedRoomDayProvider.notifier).selectDay(day);
            },
          );
        },
      ),
    );
  }
}

String _dayLabel(Day day) => switch (day) {
  Day.senin => 'Senin',
  Day.selasa => 'Selasa',
  Day.rabu => 'Rabu',
  Day.kamis => 'Kamis',
  Day.jumat => 'Jumat',
  Day.sabtu => 'Sabtu',
  Day.minggu => 'Minggu',
};

// ---------------------------------------------------------------------------
// Day-specific availability banner
// ---------------------------------------------------------------------------

class _DayAvailableBanner extends ConsumerWidget {
  const _DayAvailableBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dayAvailableCountProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room list tile
// ---------------------------------------------------------------------------

class _RoomListTile extends ConsumerWidget {
  const _RoomListTile({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(occupancyMatrixProvider);
    final selectedDay = ref.watch(selectedRoomDayProvider);
    final occupied = isRoomOccupiedOnDay(
      matrix,
      roomId: room.extId,
      day: selectedDay,
    );

    // Get the first session for preview text.
    final occupancies = getRoomDayOccupancies(
      matrix,
      roomId: room.extId,
      day: selectedDay,
    );
    final subtitle = occupancies.isNotEmpty
        ? '${occupancies.first.courseCode} · ${occupancies.first.sessionTime}'
        : (room.type == RoomType.lab ? 'Laboratorium' : 'Ruang Kelas');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: occupied ? Colors.red.shade50 : Colors.green.shade50,
        child: Icon(
          occupied ? Icons.close : Icons.check,
          color: occupied ? Colors.red.shade700 : Colors.green.shade700,
          size: 20,
        ),
      ),
      title: Text(room.name),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.push('/ruangan/${Uri.encodeComponent(room.extId)}');
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Room detail page
// ---------------------------------------------------------------------------

/// Detail page for a single room — shows sessions using that room.
class RoomDetailPage extends ConsumerWidget {
  const RoomDetailPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomByIdProvider(roomId));
    final sessions = ref.watch(roomSessionsProvider(roomId));

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruangan')),
        body: const Center(child: Text('Ruangan tidak ditemukan')),
      );
    }

    // Group sessions by day.
    final grouped = <Day, List<RoomSession>>{};
    for (final rs in sessions) {
      grouped.putIfAbsent(rs.day, () => []);
      grouped[rs.day]!.add(rs);
    }

    return Scaffold(
      appBar: AppBar(title: Text(room.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Room info card.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    room.type == RoomType.lab
                        ? Icons.computer
                        : Icons.meeting_room,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          room.type == RoomType.lab
                              ? 'Laboratorium'
                              : 'Ruang Kelas',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Schedule by day.
          if (sessions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tidak ada jadwal di ruangan ini',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (final day in kWorkdays) ...[
              if (grouped.containsKey(day)) ...[
                Text(
                  day.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...grouped[day]!.map((rs) => _RoomSessionCard(roomSession: rs)),
                const SizedBox(height: 12),
              ],
            ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room session card (detail)
// ---------------------------------------------------------------------------

class _RoomSessionCard extends StatelessWidget {
  const _RoomSessionCard({required this.roomSession});

  final RoomSession roomSession;

  @override
  Widget build(BuildContext context) {
    final session = roomSession.session;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time + type.
            Row(
              children: [
                Text(
                  session.time,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: session.type == CourseType.te
                        ? Colors.blue.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    session.type == CourseType.te ? 'Teori' : 'Praktik',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: session.type == CourseType.te
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              session.courseCode,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              session.courseName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    session.lecturer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.class_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  roomSession.classCode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Availability Matrix page — per-room grids
// ---------------------------------------------------------------------------

/// Full availability matrix: per room, grid Senin-Jumat × time slots.
class AvailabilityMatrixPage extends ConsumerWidget {
  const AvailabilityMatrixPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(occupancyMatrixProvider);
    final roomsAsync = ref.watch(roomsProvider);
    final filterMode = ref.watch(matrixFilterModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matriks Ketersediaan'),
        actions: [
          AppRefreshButton(onRefresh: () => _onRefreshRooms(context, ref)),
          PopupMenuButton<MatrixFilterMode>(
            icon: Badge(
              isLabelVisible: filterMode != MatrixFilterMode.all,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (selected) {
              ref.read(matrixFilterModeProvider.notifier).setMode(selected);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: MatrixFilterMode.all,
                child: Text('Semua'),
              ),
              const PopupMenuItem(
                value: MatrixFilterMode.availableNow,
                child: Text('Tersedia sekarang'),
              ),
            ],
          ),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (rooms) => _MatrixList(
          rooms: rooms,
          matrix: matrix,
          showAvailableOnly: filterMode == MatrixFilterMode.availableNow,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Matrix list — scrollable list of per-room grids
// ---------------------------------------------------------------------------

class _MatrixList extends ConsumerWidget {
  const _MatrixList({
    required this.rooms,
    required this.matrix,
    required this.showAvailableOnly,
  });

  final List<Room> rooms;
  final OccupancyMatrix matrix;
  final bool showAvailableOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final highlightDay = showAvailableOnly ? currentWorkDay(now) : null;
    final highlightSlot = showAvailableOnly ? currentSlotIndex(now) : null;

    // Filter rooms if "Tersedia sekarang" is active.
    final displayRooms = showAvailableOnly
        ? rooms
              .where((r) => isAvailableNow(matrix, roomId: r.extId, now: now))
              .toList()
        : rooms;

    if (showAvailableOnly && displayRooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Semua ruangan sedang terpakai',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        const _MatrixLegend(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _onRefreshRooms(context, ref),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: displayRooms.length,
              itemBuilder: (context, index) {
                final room = displayRooms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: _RoomMatrix(
                    room: room,
                    matrix: matrix,
                    highlightDay: highlightDay,
                    highlightSlot: highlightSlot,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single room matrix — Senin-Jumat × slots grid
// ---------------------------------------------------------------------------

class _RoomMatrix extends StatelessWidget {
  const _RoomMatrix({
    required this.room,
    required this.matrix,
    this.highlightDay,
    this.highlightSlot,
  });

  final Room room;
  final OccupancyMatrix matrix;
  final Day? highlightDay;
  final int? highlightSlot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room header.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Icon(
                room.type == RoomType.lab ? Icons.computer : Icons.meeting_room,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  room.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        // Grid: fitted to available width.
        LayoutBuilder(
          builder: (context, constraints) {
            const labelW = 42.0;
            final cellW = (constraints.maxWidth - labelW) / 5;
            return _buildGrid(context, cellW: cellW, labelW: labelW);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required double cellW,
    required double labelW,
  }) {
    const cellH = 40.0;
    const headerH = 28.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Table(
      defaultColumnWidth: FixedColumnWidth(cellW),
      columnWidths: {0: FixedColumnWidth(labelW)},
      children: [
        // Header row.
        TableRow(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            SizedBox(height: headerH),
            for (final day in kWorkdays)
              SizedBox(
                height: headerH,
                child: Center(
                  child: Text(
                    day.label.substring(0, 3),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Slot rows.
        for (var si = 0; si < kCanonicalSlots.length; si++)
          TableRow(
            children: [
              // Slot time label.
              Container(
                height: cellH,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _compactSlotLabel(kCanonicalSlots[si]),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Day cells with time details.
              for (final day in kWorkdays)
                _MatrixCell(
                  occupancies: getOccupancies(
                    matrix,
                    roomId: room.extId,
                    day: day,
                    slotIndex: si,
                  ),
                  isHighlighted: highlightDay == day && highlightSlot == si,
                  cellWidth: cellW,
                  cellHeight: cellH,
                ),
            ],
          ),
      ],
    );
  }
}

/// Compact slot label: "07.00-07.50" → "7:00".
String _compactSlotLabel(String slot) {
  final start = slot.split('-').first;
  final parts = start.split('.');
  final hour = int.tryParse(parts.first) ?? 0;
  return '$hour:${parts.last}';
}

// ---------------------------------------------------------------------------
// Single matrix cell — Kosong / Terpakai / Overlap
// ---------------------------------------------------------------------------

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.occupancies,
    required this.isHighlighted,
    required this.cellWidth,
    required this.cellHeight,
  });

  final List<SessionOccupancy> occupancies;
  final bool isHighlighted;
  final double cellWidth;
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    final occupied = occupancies.isNotEmpty;
    final Color bgColor = occupied
        ? (isHighlighted ? Colors.red.shade200 : Colors.red.shade50)
        : (isHighlighted ? Colors.green.shade200 : Colors.green.shade50);
    final Color borderColor = occupied
        ? Colors.red.shade300
        : Colors.green.shade300;

    return GestureDetector(
      onTap: occupied ? () => _showOccupancyDetail(context) : null,
      child: Container(
        width: cellWidth,
        height: cellHeight,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: occupied
              ? Text(
                  occupancies.first.courseCode,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        ),
      ),
    );
  }

  void _showOccupancyDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ...occupancies.map((occ) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occ.courseCode,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          Text(
                            occ.courseName,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${occ.typeLabel} · ${occ.lecturer}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Kelas: ${occ.classCode}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Matrix legend
// ---------------------------------------------------------------------------

class _MatrixLegend extends StatelessWidget {
  const _MatrixLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(
            color: Colors.green.shade100,
            border: Colors.green.shade300,
            label: 'Kosong',
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: Colors.red.shade100,
            border: Colors.red.shade300,
            label: 'Terpakai',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.border,
    required this.label,
  });

  final Color color;
  final Color border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
