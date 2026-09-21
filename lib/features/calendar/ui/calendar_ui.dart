/// Calendar feature UI — grouped month list (primary) + month-view calendar grid (secondary).
///
/// List view shows events and pengganti grouped by month with upcoming/past
/// separation, class filter, and category filter. Grid view is the existing
/// PageView month grid with improved navigation.
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
import '../../settings/data/settings_data.dart';
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
// PageView base month (2-year buffer)
// ---------------------------------------------------------------------------

final _baseMonth = DateTime(DateTime.now().year - 2, DateTime.now().month);
const _monthPageOffset = 24;

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
  String _selectedClassFilter = 'Semua';

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
        title: const Text('Acara'),
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
            classFilter: _selectedClassFilter,
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
            onClassFilterChanged: (filter) {
              setState(() {
                _selectedClassFilter = filter;
                _selectedDate = null;
              });
              if (filter != 'Semua') {
                ref.read(viewedClassProvider.notifier).select(filter);
              }
            },
            onToday: _jumpToToday,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar body — class filter + category filter + segmented control + views
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
    required this.classFilter,
    required this.onViewChanged,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onClassFilterChanged,
    required this.onToday,
  });

  final List<JtkCalendar> events;
  final DateTime currentMonth;
  final DateTime? selectedDate;
  final PageController monthPageController;
  final ScrollController listScrollController;
  final Map<String, GlobalKey> monthKeys;
  final int viewIndex;
  final String classFilter;
  final ValueChanged<int> onViewChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<String> onClassFilterChanged;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final penggantiAsync = ref.watch(penggantiProvider);

    // All pengganti entries from provider.
    final allPengganti = penggantiAsync.when(
      loading: () => <PenggantiEntry>[],
      error: (_, _) => <PenggantiEntry>[],
      data: (entries) => entries,
    );

    // Filter pengganti by class (no pengganti when 'Semua' — they're class-specific).
    final penggantiEntries = classFilter == 'Semua'
        ? <PenggantiEntry>[]
        : allPengganti.where((e) => e.classCode == classFilter).toList();

    // Filter events: 'Semua' = global only (no class_name), specific class = that class + global.
    final filteredEvents = classFilter == 'Semua'
        ? events
              .where((e) => e.className == null || e.className!.isEmpty)
              .toList()
        : events
              .where(
                (e) =>
                    e.className == null ||
                    e.className!.isEmpty ||
                    e.className == classFilter,
              )
              .toList();

    // Build dateMap for the grid view (use filtered events).
    final dateMap = _buildDateMap(filteredEvents, penggantiEntries);

    // Build month groups for the list view.
    final wib = wibNow;
    final monthGroups = classFilter == 'Semua'
        ? _buildMonthGroupsAll(
            events: filteredEvents,
            penggantiEntries: allPengganti,
            wibNow: wib,
          )
        : groupByMonth(
            events: filteredEvents,
            penggantiEntries: allPengganti,
            classCode: classFilter,
            wibNow: wib,
          );

    // Ensure GlobalKeys exist for each month header.
    for (final group in monthGroups) {
      monthKeys.putIfAbsent(group.label, () => GlobalKey());
    }

    return Column(
      children: [
        // Class selector chips (filled style).
        _ClassFilter(selected: classFilter, onSelected: onClassFilterChanged),

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
                  onToday: onToday,
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Class filter chips (filled style, single selection)
// ---------------------------------------------------------------------------

class _ClassFilter extends StatelessWidget {
  const _ClassFilter({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              showCheckmark: false,
              selectedColor: colorScheme.primaryContainer,
              side: selected == 'Semua'
                  ? null
                  : BorderSide(color: colorScheme.outline),
            ),
          ),
          for (final code in kAllClassCodes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(code),
                selected: selected == code,
                onSelected: (_) => onSelected(code),
                showCheckmark: false,
                selectedColor: colorScheme.primaryContainer,
                side: selected == code
                    ? null
                    : BorderSide(color: colorScheme.outline),
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
      return const _EmptyState(message: 'Tidak ada acara yang cocok');
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
// List event card (primary view) — redesigned with accent bar + collection time
// ---------------------------------------------------------------------------

class _ListCalendarEventCard extends StatelessWidget {
  const _ListCalendarEventCard({required this.event, required this.isUpcoming});

  final JtkCalendar event;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _categoryAccentColor(event.category);
    final startDate = DateTime.tryParse(event.date);
    final dateStr = startDate != null
        ? DateFormat('dd MMMM yyyy', 'id').format(startDate)
        : event.date;
    final multiDay = isMultiDayEvent(event);

    return Opacity(
      opacity: isUpcoming ? 1.0 : 0.55,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: isUpcoming ? 1.5 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar.
              Container(
                width: 4,
                color: isUpcoming ? accent : accent.withOpacity(0.4),
              ),
              // Content.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + category badge.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (event.category != null) ...[
                            const SizedBox(width: 8),
                            _CategoryBadge(category: event.category!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Date range (prominent).
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
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
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Collection time.
                      if (event.collectionTime != null &&
                          event.collectionTime!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Jam pengumpulan: ${event.collectionTime}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
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
    required this.onToday,
  });

  final DateTime currentMonth;
  final Map<DateTime, List<CalendarListItem>> dateMap;
  final DateTime? selectedDate;
  final PageController monthPageController;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final selectedItems = selectedDate != null
        ? dateMap[DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
          )]
        : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
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
          onToday: onToday,
        ),
        const _WeekdayHeaders(),
        SizedBox(
          height: 400,
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
        if (selectedDate == null)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Pilih tanggal untuk melihat acara',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (selectedItems == null || selectedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Tidak ada acara pada ${DateFormat('dd MMMM yyyy', 'id').format(selectedDate!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final item in selectedItems)
            switch (item) {
              CalendarEventItem(:final event) => _GridEventCard(event: event),
              CalendarPenggantiItem(:final entry) => _PenggantiCard(
                entry: entry,
              ),
            },
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month header with navigation + "Hari ini" button
// ---------------------------------------------------------------------------

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.currentMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime currentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy', 'id').format(currentMonth);
    final today = DateTime.now();
    final isCurrentMonth =
        currentMonth.year == today.year && currentMonth.month == today.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: Text(
              monthStr,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          if (!isCurrentMonth)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: onToday,
                child: const Text('Hari ini'),
              ),
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

              final colorScheme = Theme.of(context).colorScheme;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primaryContainer : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: colorScheme.primary, width: 2)
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
                                ? colorScheme.onPrimaryContainer
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
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (eventCount > 3)
                                Text(
                                  '+${eventCount - 3}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: colorScheme.onSurfaceVariant,
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
// Event card (grid tab — for the selected-date panel below the grid)
// ---------------------------------------------------------------------------

class _GridEventCard extends StatelessWidget {
  const _GridEventCard({required this.event});

  final JtkCalendar event;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _categoryAccentColor(event.category);
    final dateStr = _formatDateRange(event.date, event.endDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar.
            Container(width: 4, color: accent),
            // Content.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + category badge.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (event.category != null) ...[
                          const SizedBox(width: 8),
                          _CategoryBadge(category: event.category!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Date range (prominent).
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    // Collection time.
                    if (event.collectionTime != null &&
                        event.collectionTime!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Jam pengumpulan: ${event.collectionTime}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
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
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Get the primary date of a calendar list item.
DateTime? _itemDate(CalendarListItem item) {
  return switch (item) {
    CalendarEventItem(:final event) => DateTime.tryParse(event.date),
    CalendarPenggantiItem(:final entry) => DateTime.tryParse(entry.date),
  };
}

/// Deterministic accent color for an event category.
Color _categoryAccentColor(String? category) {
  if (category == null) return const Color(0xFF78909C); // blue grey 400
  const palette = [
    Color(0xFF1565C0), // blue 800
    Color(0xFF2E7D32), // green 800
    Color(0xFF7B1FA2), // purple 700
    Color(0xFF00838F), // cyan 800
    Color(0xFFE65100), // orange 900
    Color(0xFFC62828), // red 800
    Color(0xFF283593), // indigo 800
    Color(0xFF558B2F), // light green 800
  ];
  return palette[category.hashCode.abs() % palette.length];
}

/// Build month groups without class filtering (for 'Semua' mode).
///
/// Mirrors [groupByMonth] logic but includes all pengganti entries
/// regardless of class code.
List<CalendarMonthGroup> _buildMonthGroupsAll({
  required List<JtkCalendar> events,
  required List<PenggantiEntry> penggantiEntries,
  required DateTime wibNow,
}) {
  final items = <CalendarListItem>[
    ...events.map(CalendarEventItem.new),
    ...penggantiEntries.map(CalendarPenggantiItem.new),
  ];

  // Group by year-month.
  final monthMap = <DateTime, List<CalendarListItem>>{};
  for (final item in items) {
    final date = _itemDate(item);
    if (date == null) continue;
    final ym = DateTime(date.year, date.month);
    monthMap.putIfAbsent(ym, () => []).add(item);
  }

  // Split each month into upcoming/past.
  final result = <CalendarMonthGroup>[];
  for (final entry in monthMap.entries) {
    final upcoming = <CalendarListItem>[];
    final past = <CalendarListItem>[];

    for (final item in entry.value) {
      final date = _itemDate(item);
      if (date != null) {
        final itemDay = DateTime(date.year, date.month, date.day);
        final nowDay = DateTime(wibNow.year, wibNow.month, wibNow.day);
        if (!itemDay.isBefore(nowDay)) {
          upcoming.add(item);
        } else {
          past.add(item);
        }
      } else {
        past.add(item);
      }
    }

    // Sort upcoming ascending by date.
    upcoming.sort(
      (a, b) =>
          (_itemDate(a) ?? DateTime(0)).compareTo(_itemDate(b) ?? DateTime(0)),
    );
    // Sort past descending by date.
    past.sort(
      (a, b) =>
          (_itemDate(b) ?? DateTime(0)).compareTo(_itemDate(a) ?? DateTime(0)),
    );

    result.add(
      CalendarMonthGroup(
        yearMonth: entry.key,
        label: DateFormat('MMMM yyyy', 'id').format(entry.key),
        upcoming: upcoming,
        past: past,
      ),
    );
  }

  // Sort groups: months with upcoming items first (ascending),
  // then months with only past items (descending).
  result.sort((a, b) {
    final aHasUpcoming = a.upcoming.isNotEmpty;
    final bHasUpcoming = b.upcoming.isNotEmpty;
    if (aHasUpcoming && !bHasUpcoming) return -1;
    if (!aHasUpcoming && bHasUpcoming) return 1;
    if (aHasUpcoming) return a.yearMonth.compareTo(b.yearMonth);
    return b.yearMonth.compareTo(a.yearMonth);
  });

  return result;
}

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
