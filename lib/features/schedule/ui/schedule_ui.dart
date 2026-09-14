/// Schedule feature UI — day-chip navigation with session cards.
///
/// Displays class schedules with day chips for navigation, session cards,
/// merged consecutive slots, "Now" indicator, and pengganti banner.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/pengganti.dart';
import '../../../core/models/schedule.dart';
import '../../../core/providers/providers.dart';
import '../../../core/ui/refresh_helpers.dart';
import '../../../core/utils/time_slot.dart';
import '../../settings/data/settings_data.dart';
import '../providers/schedule_providers.dart';

// ---------------------------------------------------------------------------
// Schedule page
// ---------------------------------------------------------------------------

/// Force-refresh schedules + pengganti, bypassing ETag cache.
Future<void> _onRefreshSchedule(BuildContext context, WidgetRef ref) async {
  await refreshData(
    context,
    ref,
    endpoints: ['/api/v1/schedules', '/api/v1/pengganti'],
    refresh: () async {
      ref.invalidate(schedulesProvider);
      ref.invalidate(penggantiProvider);
      await ref.read(schedulesProvider.future);
      await ref.read(penggantiProvider.future);
    },
  );
}

/// Full-screen schedule page with class selector, day chips, and swipeable content.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  PageController? _pageController;
  String? _currentKey;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final classCode = ref.watch(viewedClassProvider);
    final schedulesAsync = ref.watch(schedulesProvider);

    final daysWithSessions = schedulesAsync.whenOrNull(
      data: (schedulesResponse) {
        final classData = schedulesResponse.classes.where(
          (c) => c.className == classCode,
        );
        if (classData.isEmpty) return <Day>[];
        return classData.first.schedule
            .where((ds) => ds.sessions.isNotEmpty)
            .map((ds) => ds.day)
            .toList();
      },
    );

    final hasDays = daysWithSessions != null && daysWithSessions.isNotEmpty;
    final effectiveDays = hasDays ? daysWithSessions : <Day>[];

    // Recreate page controller when available days change (class switch).
    if (hasDays) {
      final key = '$classCode-${effectiveDays.length}';
      if (key != _currentKey) {
        _currentKey = key;
        final idx = effectiveDays.indexOf(selectedDay);
        _pageController?.dispose();
        _pageController = PageController(initialPage: idx >= 0 ? idx : 0);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal'),
        actions: [
          AppRefreshButton(onRefresh: () => _onRefreshSchedule(context, ref)),
        ],
      ),
      body: Column(
        children: [
          // Class selector chips.
          const _ClassSelector(),
          // Day chips (visual indicator — tap animates the PageView).
          if (hasDays)
            _DayChipsRow(
              days: effectiveDays,
              selectedDay: selectedDay,
              onDaySelected: (day) {
                final idx = effectiveDays.indexOf(day);
                if (idx >= 0) {
                  _pageController?.animateToPage(
                    idx,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          // Swipeable schedule content.
          Expanded(
            child: hasDays
                ? PageView.builder(
                    controller: _pageController,
                    clipBehavior: Clip.none,
                    physics: const PageScrollPhysics(),
                    itemCount: effectiveDays.length,
                    onPageChanged: (index) {
                      ref
                          .read(selectedDayProvider.notifier)
                          .selectDay(effectiveDays[index]);
                    },
                    itemBuilder: (context, index) {
                      return _ScheduleContent(day: effectiveDays[index]);
                    },
                  )
                : const _ScheduleContent(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Class selector
// ---------------------------------------------------------------------------

class _ClassSelector extends ConsumerWidget {
  const _ClassSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewed = ref.watch(viewedClassProvider);

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: kAllClassCodes.length,
        separatorBuilder: (_, idx) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final code = kAllClassCodes[index];
          final isSelected = code == viewed;
          return ChoiceChip(
            label: Text(classLabel(code)),
            selected: isSelected,
            onSelected: (_) {
              ref.read(viewedClassProvider.notifier).select(code);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day chips row
// ---------------------------------------------------------------------------

class _DayChipsRow extends StatelessWidget {
  const _DayChipsRow({
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final List<Day> days;
  final Day selectedDay;
  final ValueChanged<Day> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final day = days[index];
          return ChoiceChip(
            label: Text(_dayLabel(day)),
            selected: day == selectedDay,
            onSelected: (_) => onDaySelected(day),
          );
        },
      ),
    );
  }

  static String _dayLabel(Day day) => switch (day) {
    Day.senin => 'Senin',
    Day.selasa => 'Selasa',
    Day.rabu => 'Rabu',
    Day.kamis => 'Kamis',
    Day.jumat => 'Jumat',
    Day.sabtu => 'Sabtu',
    Day.minggu => 'Minggu',
  };
}

// ---------------------------------------------------------------------------
// Schedule content (selected day only)
// ---------------------------------------------------------------------------

class _ScheduleContent extends ConsumerWidget {
  const _ScheduleContent({this.day});

  /// If provided, show this specific day instead of watching the provider.
  final Day? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCode = ref.watch(viewedClassProvider);
    final Day selectedDay = day ?? ref.watch(selectedDayProvider);
    final schedulesAsync = ref.watch(schedulesProvider);
    final penggantiAsync = ref.watch(penggantiProvider);
    final isToday = isSelectedDayToday(selectedDay);

    return schedulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Gagal memuat jadwal',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      data: (schedulesResponse) {
        final classData = schedulesResponse.classes.where(
          (c) => c.className == classCode,
        );
        if (classData.isEmpty) {
          return const Center(child: Text('Data kelas tidak ditemukan'));
        }

        final classSchedule = classData.first.schedule;

        return RefreshIndicator(
          onRefresh: () => _onRefreshSchedule(context, ref),
          child: penggantiAsync.when(
            loading: () =>
                _buildDay(classCode, classSchedule, [], selectedDay, isToday),
            error: (e, _) =>
                _buildDay(classCode, classSchedule, [], selectedDay, isToday),
            data: (penggantiEntries) => _buildDay(
              classCode,
              classSchedule,
              penggantiEntries,
              selectedDay,
              isToday,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDay(
    String classCode,
    List<DaySchedule> classSchedule,
    List<PenggantiEntry> penggantiEntries,
    Day selectedDay,
    bool isToday,
  ) {
    final date = dayToDate(selectedDay);
    final dayData = resolveDaySchedule(
      classCode: classCode,
      date: date,
      classSchedule: classSchedule,
      penggantiEntries: penggantiEntries,
    );

    return _DayScheduleList(
      dayData: dayData,
      date: date,
      showNowIndicator: isToday,
    );
  }
}

// ---------------------------------------------------------------------------
// Single day schedule list
// ---------------------------------------------------------------------------

class _DayScheduleList extends StatelessWidget {
  const _DayScheduleList({
    required this.dayData,
    required this.date,
    this.showNowIndicator = true,
  });

  final DayScheduleData dayData;
  final DateTime date;
  final bool showNowIndicator;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sessions = dayData.mergedSessions;

    // Build list of widgets including istirahat gaps between sessions.
    final children = <Widget>[];

    // Pengganti banner.
    if (dayData.penggantiNote != null) {
      children.add(_PenggantiBanner(note: dayData.penggantiNote!));
    }

    if (dayData.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'Tidak ada jadwal',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    } else {
      for (var i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        final isActive = showNowIndicator && isSessionActive(session, now);
        children.add(_SessionCard(session: session, isActive: isActive));

        // Add istirahat gap between consecutive sessions.
        if (i < sessions.length - 1) {
          final gapMinutes = _gapMinutes(
            session.endTime,
            sessions[i + 1].startTime,
          );
          if (gapMinutes > 0) {
            children.add(
              _IstirahatGap(
                from: session.endTime,
                to: sessions[i + 1].startTime,
                minutes: gapMinutes,
              ),
            );
          }
        }
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: children,
    );
  }

  /// Calculate gap in minutes between two dot-time strings.
  static int _gapMinutes(String endTime, String nextStartTime) {
    final end = WibTime.parse(endTime);
    final start = WibTime.parse(nextStartTime);
    if (end == null || start == null) return 0;
    return start.totalMinutes - end.totalMinutes;
  }
}

// ---------------------------------------------------------------------------
// Istirahat gap widget
// ---------------------------------------------------------------------------

class _IstirahatGap extends StatelessWidget {
  const _IstirahatGap({
    required this.from,
    required this.to,
    required this.minutes,
  });

  final String from;
  final String to;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Istirahat $from–$to',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.isActive});

  final MergedSession session;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () => _showDetailSheet(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isActive
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        elevation: isActive ? 3 : 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time range + type badge row.
              Row(
                children: [
                  // Now indicator.
                  if (isActive)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      session.timeRange,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Type badge.
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
                      session.typeLabel,
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
              // Course code.
              Text(
                session.courseCode,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              // Course name.
              Text(
                session.courseName,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Room.
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      session.room,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              // Lecturer(s).
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _SessionDetailSheet(session: session),
    );
  }
}

// ---------------------------------------------------------------------------
// Session detail bottom sheet (long-press)
// ---------------------------------------------------------------------------

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({required this.session});

  final MergedSession session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Type badge.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: session.type == CourseType.te
                    ? Colors.blue.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                session.typeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: session.type == CourseType.te
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Course code + name.
            Text(
              session.courseCode,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              session.courseName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Time.
            _DetailRow(
              icon: Icons.access_time,
              label: 'Waktu',
              value: session.timeRange,
            ),
            const SizedBox(height: 8),
            // Room.
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Ruang',
              value: session.room,
            ),
            const SizedBox(height: 8),
            // Lecturer(s).
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Dosen',
              value: session.lecturer,
            ),
            if (session.originalSessions.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Jadwal ini merupakan gabungan ${session.originalSessions.length} sesi',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pengganti banner
// ---------------------------------------------------------------------------

class _PenggantiBanner extends StatelessWidget {
  const _PenggantiBanner({required this.note});

  final PenggantiNote note;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (color, icon, label) = switch (note.kind) {
      PenggantiKind.replace => (
        Colors.orange.shade50,
        Icons.swap_horiz,
        'JADWAL PENGGANTI',
      ),
      PenggantiKind.add => (
        Colors.blue.shade50,
        Icons.add_circle_outline,
        'PENGGANTI TAMBAHAN',
      ),
      PenggantiKind.info => (
        Colors.grey.shade100,
        Icons.info_outline,
        'INFO PENGGANTI',
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (note.hasNote)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note.noteText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
