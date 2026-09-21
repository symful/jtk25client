/// Calendar feature UI — grouped month list (primary) + month-view calendar grid (secondary).
///
/// List view shows events and pengganti grouped by month with upcoming/past
/// separation and category filter. Grid view is the existing PageView month grid.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/calendar.dart';
import '../../../core/models/pengganti.dart';
import '../../../core/providers/providers.dart';
import '../../../core/ui/refresh_helpers.dart';
import '../../../core/utils/wib_now.dart';
import '../../schedule/providers/schedule_providers.dart';
import '../data/calendar_data.dart';

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------

/// Refresh calendar: invalidate provider → await → change detection.
Future<void> _onRefreshCalendar(BuildContext context, WidgetRef ref) async {
  await refreshData(
    context,
    ref,
    endpoints: ['/api/v1/calendar'],
    refresh: () async {
      ref.invalidate(calendarProvider);
      ref.invalidate(penggantiProvider);
      await ref.read(calendarProvider.future);
      await ref.read(penggantiProvider.future);
    },
  );
}

// ---------------------------------------------------------------------------
// PageView base month (10-year buffer)
// ---------------------------------------------------------------------------

final _baseMonth = DateTime(DateTime.now().year - 10, DateTime.now().month);
const _monthPageOffset = 120;

// ---------------------------------------------------------------------------
// Calendar page
// ---------------------------------------------------------------------------

/// Full-screen calendar page with grouped month list (primary) and
/// month grid (secondary), switchable via SegmentedButton.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  int _viewIndex = 0; // 0 = Daftar (list), 1 = Kalender (grid)
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  late final PageController _monthPageController;
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _monthKeys = {};
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _monthPageController = PageController(initialPage: _monthPageOffset);
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  /// Jump to today: scroll list to current month / jump grid to current month.
  void _jumpToToday() {
    final today = wibNow;
    if (_viewIndex == 0) {
      // List view — scroll to current month section.
      final label = DateFormat(
        'MMMM yyyy',
        'id',
      ).format(DateTime(today.year, today.month));
      final key = _monthKeys[label];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Grid view — jump PageView to current month.
      final monthsDiff =
          (today.year - _baseMonth.year) * 12 +
          (today.month - _baseMonth.month);
      _monthPageController.animateToPage(
        monthsDiff,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Lompat ke hari ini',
            onPressed: _jumpToToday,
          ),
          AppRefreshButton(onRefresh: () => _onRefreshCalendar(context, ref)),
        ],
      ),
      body: calendarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gagal memuat kalender',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _onRefreshCalendar(context, ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (allEvents) {
          return _CalendarBody(
            events: allEvents,
            currentMonth: _currentMonth,
            selectedDate: _selectedDate,
            monthPageController: _monthPageController,
            listScrollController: _listScrollController,
            monthKeys: _monthKeys,
            viewIndex: _viewIndex,
            selectedCategory: _selectedCategory,
            onViewChanged: (index) => setState(() => _viewIndex = index),
            onMonthChanged: (month) {
              setState(() {
                _currentMonth = month;
                _selectedDate = null;
              });
            },
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
            },
            onCategoryChanged: (cat) {
              setState(() => _selectedCategory = cat);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar body — segmented control + view content
// ---------------------------------------------------------------------------

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.events,
    required this.currentMonth,
    required this.selectedDate,
    required this.monthPageController,
    required this.listScrollController,
    required this.monthKeys,
    required this.viewIndex,
    required this.selectedCategory,
    required this.onViewChanged,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onCategoryChanged,
  });

  final List<JtkCalendar> events;
  final DateTime currentMonth;
  final DateTime? selectedDate;
  final PageController monthPageController;
  final ScrollController listScrollController;
  final Map<String, GlobalKey> monthKeys;
  final int viewIndex;
  final String selectedCategory;
  final ValueChanged<int> onViewChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCode = ref.watch(viewedClassProvider);
    final penggantiAsync = ref.watch(penggantiProvider);

    // Filter events by category.
    final filteredEvents = selectedCategory == 'Semua'
        ? events
        : events.where((e) => e.category == selectedCategory).toList();

    // Collect pengganti entries for the viewed class.
    final penggantiEntries = penggantiAsync.when(
      loading: () => <PenggantiEntry>[],
      error: (_, _) => <PenggantiEntry>[],
      data: (entries) =>
          entries.where((e) => e.classCode == classCode).toList(),
    );

    // Distinct categories from all events.
    final categories = distinctCategories(events);

    // Build dateMap for the grid view (same logic as before).
    final dateMap = _buildDateMap(events, penggantiEntries);

    // Build month groups for the list view.
    final monthGroups = groupByMonth(
      events: filteredEvents,
      penggantiEntries: penggantiEntries,
      classCode: classCode,
      wibNow: wibNow,
    );

    // Ensure GlobalKeys exist for each month header.
    for (final group in monthGroups) {
      monthKeys.putIfAbsent(group.label, () => GlobalKey());
    }

    return Column(
      children: [
        // Category filter chips.
        if (categories.isNotEmpty)
          _CategoryFilter(
            categories: categories,
            selected: selectedCategory,
            onSelected: onCategoryChanged,
          ),

        // Segmented control: Daftar | Kalender.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Daftar'),
                icon: Icon(Icons.list),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Kalender'),
                icon: Icon(Icons.calendar_month),
              ),
            ],
            selected: {viewIndex},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onViewChanged(selection.first);
            },
          ),
        ),

        // View content.
        Expanded(
          child: viewIndex == 0
              ? _GroupedMonthList(
                  monthGroups: monthGroups,
                  monthKeys: monthKeys,
                  scrollController: listScrollController,
                )
              : _GridView(
                  currentMonth: currentMonth,
                  dateMap: dateMap,
                  selectedDate: selectedDate,
                  monthPageController: monthPageController,
                  onMonthChanged: onMonthChanged,
                  onDateSelected: onDateSelected,
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category filter chips
// ---------------------------------------------------------------------------

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('Semua'),
              selected: selected == 'Semua',
              onSelected: (_) => onSelected('Semua'),
            ),
          ),
          for (final cat in categories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(cat),
                selected: selected == cat,
                onSelected: (_) => onSelected(cat),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped month list (primary view)
// ---------------------------------------------------------------------------

class _GroupedMonthList extends StatelessWidget {
  const _GroupedMonthList({
    required this.monthGroups,
    required this.monthKeys,
    required this.scrollController,
  });

  final List<CalendarMonthGroup> monthGroups;
  final Map<String, GlobalKey> monthKeys;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (monthGroups.isEmpty) {
      return const Center(child: Text('Tidak ada acara'));
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final group in monthGroups) ...[
          // Month section header.
          Container(
            key: monthKeys[group.label],
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              group.label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),

          // Upcoming items.
          for (final item in group.upcoming)
            _buildCalendarItem(context, item, isUpcoming: true),

          // Past items section divider.
          if (group.past.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Selesai',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final item in group.past)
              _buildCalendarItem(context, item, isUpcoming: false),
          ],
        ],
      ],
    );
  }

  Widget _buildCalendarItem(
    BuildContext context,
    CalendarListItem item, {
    required bool isUpcoming,
  }) {
    return switch (item) {
      CalendarEventItem(:final event) => _ListCalendarEventCard(
        event: event,
        isUpcoming: isUpcoming,
      ),
      CalendarPenggantiItem(:final entry) => _PenggantiCard(entry: entry),
    };
  }
}

// ---------------------------------------------------------------------------
// List event card (primary view)
// ---------------------------------------------------------------------------

class _ListCalendarEventCard extends StatelessWidget {
  const _ListCalendarEventCard({required this.event, required this.isUpcoming});

  final JtkCalendar event;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startDate = DateTime.tryParse(event.date);
    final dateStr = startDate != null
        ? DateFormat('dd MMMM yyyy', 'id').format(startDate)
        : event.date;
    final multiDay = isMultiDayEvent(event);

    return Opacity(
      opacity: isUpcoming ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: isUpcoming
            ? RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
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
              // Date + multi-day badge.
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14),
                  const SizedBox(width: 6),
                  Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
                  if (multiDay) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        's/d ${DateFormat('dd MMM', 'id').format(DateTime.tryParse(event.endDate) ?? DateTime.now())}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid view (secondary) — existing PageView month grid
// ---------------------------------------------------------------------------

class _GridView extends StatelessWidget {
  const _GridView({
    required this.currentMonth,
    required this.dateMap,
    required this.selectedDate,
    required this.monthPageController,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime currentMonth;
  final Map<DateTime, List<CalendarListItem>> dateMap;
  final DateTime? selectedDate;
  final PageController monthPageController;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
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
          onPrev: () => monthPageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
          onNext: () => monthPageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        ),
        const _WeekdayHeaders(),
        Expanded(
          flex: 3,
          child: PageView.builder(
            controller: monthPageController,
            clipBehavior: Clip.none,
            physics: const PageScrollPhysics(),
            onPageChanged: (page) {
              final month = DateTime(_baseMonth.year, _baseMonth.month + page);
              onMonthChanged(month);
            },
            itemBuilder: (context, page) {
              final month = DateTime(_baseMonth.year, _baseMonth.month + page);
              return _CalendarGrid(
                currentMonth: month,
                dateMap: dateMap,
                selectedDate: selectedDate,
                onDateSelected: onDateSelected,
              );
            },
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
// Calendar grid (month view) — dots polished: 7px, up to 3 + '+N'
// ---------------------------------------------------------------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.currentMonth,
    required this.dateMap,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime currentMonth;
  final Map<DateTime, List<CalendarListItem>> dateMap;
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
              final eventCount = hasItems
                  ? items.whereType<CalendarEventItem>().length
                  : 0;
              final hasPengganti =
                  hasItems && items.any((i) => i is CalendarPenggantiItem);

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
                              if (hasPengganti)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              // Show up to 3 event dots.
                              for (var i = 0; i < math.min(eventCount, 3); i++)
                                Container(
                                  width: 7,
                                  height: 7,
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
                              if (eventCount > 3)
                                Text(
                                  '+${eventCount - 3}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
// Event list for selected date (grid tab)
// ---------------------------------------------------------------------------

class _EventListForDate extends StatelessWidget {
  const _EventListForDate({required this.date, required this.items});

  final DateTime? date;
  final List<CalendarListItem>? items;

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
        return switch (item) {
          CalendarEventItem(:final event) => _GridEventCard(event: event),
          CalendarPenggantiItem(:final entry) => _PenggantiCard(entry: entry),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Event card (grid tab — for the selected-date panel below the grid)
// ---------------------------------------------------------------------------

class _GridEventCard extends StatelessWidget {
  const _GridEventCard({required this.event});

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
// Pengganti card (reused by both list and grid views)
// ---------------------------------------------------------------------------

class _PenggantiCard extends StatelessWidget {
  const _PenggantiCard({required this.entry});

  final PenggantiEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (color, icon, kindLabel) = switch (entry.kind) {
      PenggantiKind.replace => (
        Colors.orange.shade50,
        Icons.swap_horiz,
        'Ganti',
      ),
      PenggantiKind.add => (
        Colors.blue.shade50,
        Icons.add_circle_outline,
        'Tambah',
      ),
      PenggantiKind.info => (Colors.grey.shade100, Icons.info_outline, 'Info'),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: switch (entry.kind) {
                PenggantiKind.replace => Colors.orange,
                PenggantiKind.add => Colors.blue,
                PenggantiKind.info => Colors.grey,
              },
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: colorScheme.onSurface),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      kindLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: switch (entry.kind) {
                          PenggantiKind.replace => Colors.orange.shade800,
                          PenggantiKind.add => Colors.blue.shade800,
                          PenggantiKind.info => Colors.grey.shade700,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.classCode,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (entry.sessions.isNotEmpty)
                    Chip(
                      label: Text(
                        '${entry.sessions.length} sesi',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
              if (entry.note != null && entry.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.note!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
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

/// Build the date→items map for the grid view's dateMap.
Map<DateTime, List<CalendarListItem>> _buildDateMap(
  List<JtkCalendar> events,
  List<PenggantiEntry> penggantiEntries,
) {
  final dateMap = <DateTime, List<CalendarListItem>>{};

  // Add campus events (both start and end dates).
  for (final event in events) {
    final eventDate = DateTime.tryParse(event.date);
    if (eventDate != null) {
      final key = DateTime(eventDate.year, eventDate.month, eventDate.day);
      dateMap.putIfAbsent(key, () => []).add(CalendarEventItem(event));
    }
    final endDate = DateTime.tryParse(event.endDate);
    // Only add to end-date slot if it's a different day.
    if (endDate != null &&
        eventDate != null &&
        !(endDate.year == eventDate.year &&
            endDate.month == eventDate.month &&
            endDate.day == eventDate.day)) {
      final key = DateTime(endDate.year, endDate.month, endDate.day);
      dateMap.putIfAbsent(key, () => []).add(CalendarEventItem(event));
    }
  }

  // Add pengganti entries.
  for (final entry in penggantiEntries) {
    final entryDate = DateTime.tryParse(entry.date);
    if (entryDate == null) continue;
    final key = DateTime(entryDate.year, entryDate.month, entryDate.day);
    dateMap.putIfAbsent(key, () => []).add(CalendarPenggantiItem(entry));
  }

  return dateMap;
}

String _formatDateRange(String startIso, String endIso) {
  final start = DateTime.tryParse(startIso);
  final end = DateTime.tryParse(endIso);
  if (start == null || end == null) return '$startIso – $endIso';

  final fmt = DateFormat('dd MMM yyyy', 'id');
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
