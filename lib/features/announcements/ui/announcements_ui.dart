/// Announcements feature UI — list + detail pages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/announcement.dart';
import '../providers/announcements_providers.dart';

// ---------------------------------------------------------------------------
// Announcements list page
// ---------------------------------------------------------------------------

/// Full-screen list of active announcements.
class AnnouncementsListPage extends ConsumerWidget {
  const AnnouncementsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(filteredAnnouncementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _OfflineBanner(
          child: Center(
            child: Text(
              'Gagal memuat pengumuman',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada pengumuman'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(filteredAnnouncementsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final a = items[i];
                return _AnnouncementTile(announcement: a);
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _AnnouncementTile extends ConsumerWidget {
  const _AnnouncementTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(announcementsSeenProvider);
    final isSeen = seen.hasSeen(announcement.id);

    final dateStr = _formatDate(announcement.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: !isSeen
            ? const Badge(label: Text('Baru'))
            : (announcement.pinned
                  ? const Icon(Icons.push_pin, color: Colors.orange, size: 20)
                  : null),
        title: Text(
          announcement.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$dateStr${announcement.pinned ? ' · Disematkan' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Mark as seen.
          ref.read(announcementsSeenProvider).markSeen(announcement.id);
          // Navigate to detail.
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AnnouncementDetailPage(announcement: announcement),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail page (markdown body)
// ---------------------------------------------------------------------------

class AnnouncementDetailPage extends StatelessWidget {
  const AnnouncementDetailPage({super.key, required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final createdStr = _formatDate(announcement.createdAt);
    final expiresStr = announcement.expiresAt != null
        ? _formatDate(announcement.expiresAt!)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(announcement.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metadata row.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(createdStr)),
              if (announcement.pinned)
                const Chip(
                  avatar: Icon(Icons.push_pin, size: 16),
                  label: Text('Disematkan'),
                ),
              if (expiresStr != null)
                Chip(label: Text('Berakhir: $expiresStr')),
            ],
          ),
          const SizedBox(height: 16),
          // Markdown body.
          MarkdownBody(data: announcement.body),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline banner wrapper
// ---------------------------------------------------------------------------

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MaterialBanner(
          content: const Text('Mode offline — menampilkan data tersimpan'),
          leading: const Icon(Icons.wifi_off),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('Tutup'),
            ),
          ],
        ),
        Expanded(child: child),
      ],
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
