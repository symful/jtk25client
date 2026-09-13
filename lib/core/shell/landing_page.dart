/// Landing page — dashboard showing today's schedule quick-jump,
/// top-3 announcements, and upcoming-3 events.
///
/// All strings in Bahasa Indonesia. Lean layout for fast loading.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../features/announcements/providers/announcements_providers.dart';
import '../../features/events/providers/events_providers.dart';
import '../../features/settings/data/settings_data.dart';
import '../../features/schedule/providers/schedule_providers.dart';
import '../../core/models/event.dart';
import '../../core/models/announcement.dart';

/// Landing dashboard — today schedule per class + announcements + events.
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JTK25'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/pengaturan'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Today's schedule section.
          const _SectionTitle(label: 'Jadwal Hari Ini'),
          const SizedBox(height: 8),
          const _ClassGrid(),
          const SizedBox(height: 24),

          // Announcements section.
          const _SectionTitle(label: 'Pengumuman Terbaru'),
          const SizedBox(height: 8),
          const _TopAnnouncements(),
          const SizedBox(height: 24),

          // Events section.
          const _SectionTitle(label: 'Acara Mendatang'),
          const SizedBox(height: 8),
          const _UpcomingEvents(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ---------------------------------------------------------------------------
// Class grid — quick jump cards for each class
// ---------------------------------------------------------------------------

class _ClassGrid extends ConsumerWidget {
  const _ClassGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedClassProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAllClassCodes.map((code) {
        final isSelected = code == selected;
        return SizedBox(
          width: 140,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                ref.read(selectedClassProvider.notifier).select(code);
                context.push('/jadwal/${Uri.encodeComponent(code)}');
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.class_,
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            code,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSelected ? 'Terpilih' : 'Lihat jadwal',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Top announcements (max 3)
// ---------------------------------------------------------------------------

class _TopAnnouncements extends ConsumerWidget {
  const _TopAnnouncements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(filteredAnnouncementsProvider);

    return asyncItems.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Belum ada pengumuman',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }
        final top3 = items.take(3).toList();
        return Column(
          children: top3
              .map((a) => _AnnouncementQuickTile(announcement: a))
              .toList(),
        );
      },
    );
  }
}

class _AnnouncementQuickTile extends StatelessWidget {
  const _AnnouncementQuickTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(announcement.createdAt);

    return Card(
      child: ListTile(
        leading: announcement.pinned
            ? const Icon(Icons.push_pin, color: Colors.orange, size: 20)
            : null,
        title: Text(
          announcement.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/pengumuman'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming events (max 3)
// ---------------------------------------------------------------------------

class _UpcomingEvents extends ConsumerWidget {
  const _UpcomingEvents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(groupedEventsProvider);

    return asyncGroups.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (groups) {
        // Find the "Akan Datang" group.
        final upcoming = groups
            .where((g) => g.label == 'Akan Datang')
            .expand((g) => g.items)
            .take(3)
            .toList();

        if (upcoming.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.event_busy,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Belum ada acara mendatang',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: upcoming.map((e) => _EventQuickTile(event: e)).toList(),
        );
      },
    );
  }
}

class _EventQuickTile extends StatelessWidget {
  const _EventQuickTile({required this.event});

  final JtkEvent event;

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDateRange(event.date, event.endDate);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.event, size: 20),
        title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/acara'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('dd MMM yyyy', 'id').format(dt);
}

String _formatDateRange(String startIso, String endIso) {
  final start = DateTime.tryParse(startIso);
  final end = DateTime.tryParse(endIso);
  if (start == null || end == null) return '$startIso – $endIso';
  final fmt = DateFormat('dd MMM yyyy', 'id');
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
