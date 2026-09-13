/// Rooms feature UI — searchable room list, detail, and availability matrix.
///
/// Shows room occupancy across Senin–Jumat × time slots. Supports
/// "Tersedia sekarang" toggle and overlap markers.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/room.dart';
import '../../../core/models/schedule.dart';
import '../../../core/providers/providers.dart';
import '../data/rooms_data.dart';
import '../providers/rooms_providers.dart';

// ---------------------------------------------------------------------------
// Rooms list page
// ---------------------------------------------------------------------------

/// Full-screen searchable room list with availability summary.
class RoomsListPage extends ConsumerWidget {
  const RoomsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ruangan')),
      body: Column(
        children: [
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
          // Available now summary.
          const _AvailableNowBanner(),
          // Room list.
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada ruangan ditemukan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _RoomListTile(room: filtered[index]);
                    },
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Available now banner
// ---------------------------------------------------------------------------

class _AvailableNowBanner extends ConsumerWidget {
  const _AvailableNowBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(availableNowSummaryProvider);

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
    final now = DateTime.now();
    final available = isAvailableNow(matrix, roomId: room.id, now: now);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: available ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          available ? Icons.check : Icons.close,
          color: available ? Colors.green.shade700 : Colors.red.shade700,
          size: 20,
        ),
      ),
      title: Text(room.name),
      subtitle: Text(
        room.type == RoomType.lab ? 'Laboratorium' : 'Ruang Kelas',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.push('/ruangan/${Uri.encodeComponent(room.id)}');
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
              .where((r) => isAvailableNow(matrix, roomId: r.id, now: now))
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
          child: ListView.builder(
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
        // Grid: header + slot rows.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildGrid(context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    const cellW = 64.0;
    const cellH = 32.0;
    const labelW = 52.0;
    const headerH = 28.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(cellW),
      columnWidths: {0: const FixedColumnWidth(labelW)},
      children: [
        // Header row.
        TableRow(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            SizedBox(height: headerH), // Empty corner.
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
                  kCanonicalSlots[si].split('-').first,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Day cells.
              for (final day in kWorkdays)
                _MatrixCell(
                  occupancies: getOccupancies(
                    matrix,
                    roomId: room.id,
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
    final count = occupancies.length;
    final Color bgColor;
    final Color borderColor;

    if (count == 0) {
      bgColor = isHighlighted ? Colors.green.shade200 : Colors.green.shade50;
      borderColor = Colors.green.shade300;
    } else if (count == 1) {
      bgColor = isHighlighted ? Colors.red.shade200 : Colors.red.shade50;
      borderColor = Colors.red.shade300;
    } else {
      bgColor = isHighlighted ? Colors.orange.shade200 : Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
    }

    return GestureDetector(
      onTap: count > 0 ? () => _showOccupancyDetail(context) : null,
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
          child: count == 0
              ? null // Kosong
              : count == 1
              ? const Icon(Icons.close, size: 12, color: Colors.red)
              : Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
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
              if (occupancies.length > 1)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠ OVERLAP: ${occupancies.length} jadwal di slot yang sama',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
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
          const SizedBox(width: 16),
          _LegendItem(
            color: Colors.orange.shade100,
            border: Colors.orange.shade300,
            label: 'Overlap',
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
