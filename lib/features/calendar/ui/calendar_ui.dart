/// Calendar feature UI — month-view calendar grid with event indicators.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/calendar.dart';
import '../../../core/providers/providers.dart';
import '../../../core/ui/refresh_helpers.dart';
import '../data/calendar_data.dart';

// ---------------------------------------------------------------------------
// Calendar page
// ---------------------------------------------------------------------------

/// A single item on the calendar grid: a campus [JtkCalendar] event.
class _CalendarItem {
  const _CalendarItem(this.event);

  final JtkCalendar event;
}

// ---------------------------------------------------------------------------
// Calendar page
// ---------------------------------------------------------------------------

/// Refresh calendar: invalidate provider → await → change detection.
Future<void> _onRefreshCalendar(BuildContext context, WidgetRef ref) async {
  await refreshData(
    context,
    ref,
    endpoints: ['/api/v1/calendar'],
    refresh: () async {
      ref.invalidate(calendarProvider);
      await ref.read(calendarProvider.future);
    },
  );
}

/// Full-screen calendar page with month grid and event list below.
///
/// Watches [calendarProvider] directly for loading/error/data.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          AppRefreshButton(onRefresh: () => _onRefreshCalendar(context, ref)),
        ],
      ),
      body: calendarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Gagal memuat kalender',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (allEvents) {
          return _CalendarBody(
            events: allEvents,
            currentMonth: _currentMonth,
            selectedDate: _selectedDate,
            onMonthChanged: (delta) {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + delta,
                );
                _selectedDate = null;
              });
            },
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar body
// ---------------------------------------------------------------------------

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.events,
    required this.currentMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final List<JtkCalendar> events;
  final DateTime currentMonth;
  final DateTime? selectedDate;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateMap = <DateTime, List<_CalendarItem>>{};

    // Always add campus events.
    for (final event in events) {
      final eventDate = DateTime.tryParse(event.date);
      if (eventDate != null) {
        final key = DateTime(eventDate.year, eventDate.month, eventDate.day);
        dateMap.putIfAbsent(key, () => []).add(_CalendarItem(event));
      }
      final endDate = DateTime.tryParse(event.endDate);
      // Only add to end-date slot if it's a different day (not just different time).
      if (endDate != null &&
          eventDate != null &&
          !(endDate.year == eventDate.year &&
              endDate.month == eventDate.month &&
              endDate.day == eventDate.day)) {
        final key = DateTime(endDate.year, endDate.month, endDate.day);
        dateMap.putIfAbsent(key, () => []).add(_CalendarItem(event));
      }
    }

    final selectedItems = selectedDate != null
        ? dateMap[DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
          )]
        : null;

    return Column(
      children: [
        _MonthHeader(
          currentMonth: currentMonth,
          onPrev: () => onMonthChanged(-1),
          onNext: () => onMonthChanged(1),
        ),
        const _WeekdayHeaders(),
        Expanded(
          flex: 3,
          child: _CalendarGrid(
            currentMonth: currentMonth,
            dateMap: dateMap,
            selectedDate: selectedDate,
            onDateSelected: onDateSelected,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: _EventListForDate(date: selectedDate, items: selectedItems),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month header with navigation
// ---------------------------------------------------------------------------

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy', 'id').format(currentMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text(
            monthStr,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday headers (Sen-Sen)
// ---------------------------------------------------------------------------

class _WeekdayHeaders extends StatelessWidget {
  const _WeekdayHeaders();

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _days.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar grid (month view)
// ---------------------------------------------------------------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.currentMonth,
    required this.dateMap,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime currentMonth;
  final Map<DateTime, List<_CalendarItem>> dateMap;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;

    // Monday=1 ... Sunday=7
    int startWeekday = firstDay.weekday;
    // Shift so Monday=0 ... Sunday=6
    final emptyCells = startWeekday - 1;

    final totalCells = emptyCells + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - emptyCells + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox.shrink());
              }

              final date = DateTime(
                currentMonth.year,
                currentMonth.month,
                dayNum,
              );
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected =
                  selectedDate != null &&
                  date.year == selectedDate!.year &&
                  date.month == selectedDate!.month &&
                  date.day == selectedDate!.day;
              final key = DateTime(date.year, date.month, date.day);
              final items = dateMap[key];
              final hasItems = items != null && items.isNotEmpty;
              final dotCount = hasItems ? items.length : 0;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDateSelected(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : null,
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : null,
                          ),
                        ),
                        if (hasItems) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var i = 0;
                                i < (dotCount > 3 ? 3 : dotCount);
                                i++
                              )
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Event list for selected date
// ---------------------------------------------------------------------------

class _EventListForDate extends StatelessWidget {
  const _EventListForDate({required this.date, required this.items});

  final DateTime? date;
  final List<_CalendarItem>? items;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Center(
        child: Text(
          'Pilih tanggal untuk melihat acara',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (items == null || items!.isEmpty) {
      final dateStr = DateFormat('dd MMMM yyyy', 'id').format(date!);
      return Center(
        child: Text(
          'Tidak ada acara pada $dateStr',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items!.length,
      itemBuilder: (context, index) {
        final item = items![index];
        return _CalendarEventCard(event: item.event);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Event card (same design as original but adapted for JtkCalendar)
// ---------------------------------------------------------------------------

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({required this.event});

  final JtkCalendar event;

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDateRange(event.date, event.endDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + category badge.
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (event.category != null) ...[
                  const SizedBox(width: 8),
                  _CategoryBadge(category: event.category!),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Date range.
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14),
                const SizedBox(width: 6),
                Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            // Location chip.
            if (event.location != null) ...[
              const SizedBox(height: 6),
              _LocationChip(location: event.location!),
            ],
            // Description (rendered as Markdown).
            if (event.description != null) ...[
              const SizedBox(height: 8),
              MarkdownBody(
                data: event.description!,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category badge
// ---------------------------------------------------------------------------

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location chip — taps URL/geo via url_launcher
// ---------------------------------------------------------------------------

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final isUrl = isLocationUrl(location);

    return InkWell(
      onTap: isUrl ? () => _openLocation(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              location,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isUrl ? Theme.of(context).colorScheme.primary : null,
                decoration: isUrl ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocation(BuildContext context) async {
    final uri = Uri.parse(location);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka lokasi')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatDateRange(String startIso, String endIso) {
  final start = DateTime.tryParse(startIso);
  final end = DateTime.tryParse(endIso);
  if (start == null || end == null) return '$startIso – $endIso';

  final fmt = DateFormat('dd MMM yyyy', 'id');
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
