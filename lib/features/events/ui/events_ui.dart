/// Events feature UI — grouped card list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/event.dart';
import '../../../core/providers/providers.dart';
import '../../../core/ui/refresh_helpers.dart';
import '../data/events_data.dart';
import '../providers/events_providers.dart';

// ---------------------------------------------------------------------------
// Events list page
// ---------------------------------------------------------------------------

/// Refresh events: invalidate provider → await → change detection.
Future<void> _onRefreshEvents(BuildContext context, WidgetRef ref) async {
  await refreshData(
    context,
    ref,
    endpoints: ['/api/v1/events'],
    refresh: () async {
      ref.invalidate(eventsProvider);
      await ref.read(eventsProvider.future);
    },
  );
}

/// Full-screen grouped events page.
///
/// Watches [eventsProvider] directly for loading/error/data
/// (same pattern as schedule_ui.dart watches schedulesProvider).
class EventsListPage extends ConsumerWidget {
  const EventsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acara'),
        actions: [
          AppRefreshButton(onRefresh: () => _onRefreshEvents(context, ref)),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Gagal memuat acara',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (_) {
          // Grouped data comes from the sync derivation.
          final groups = ref.watch(groupedEventsProvider);
          if (groups.isEmpty) {
            return const Center(child: Text('Belum ada acara'));
          }
          return RefreshIndicator(
            onRefresh: () => _onRefreshEvents(context, ref),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.fold<int>(
                0,
                (sum, g) => sum + g.items.length + 1,
              ),
              itemBuilder: (context, i) {
                int cursor = 0;
                for (final group in groups) {
                  // Section header
                  if (i == cursor) {
                    return _SectionHeader(label: group.label);
                  }
                  cursor++;
                  // Items
                  for (int j = 0; j < group.items.length; j++) {
                    if (i == cursor) {
                      return _EventCard(event: group.items[j]);
                    }
                    cursor++;
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event card
// ---------------------------------------------------------------------------

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final JtkEvent event;

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
            // Description preview.
            if (event.description != null) ...[
              const SizedBox(height: 8),
              Text(
                event.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
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
