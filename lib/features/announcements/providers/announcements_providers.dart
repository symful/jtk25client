/// Announcements feature providers.
///
/// Depends on T8's `announcementsProvider` for data and adds:
/// - Seen-ID tracking (Hive box)
/// - Filtered / sorted list (pinned first, expired removed)
/// - Red-dot indicator
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/announcement.dart';
import '../../../core/providers/providers.dart';
import '../data/announcements_data.dart';

// ---------------------------------------------------------------------------
// Seen-IDs persistence
// ---------------------------------------------------------------------------

/// Singleton [AnnouncementsSeen] manager.
final announcementsSeenProvider = Provider<AnnouncementsSeen>((ref) {
  final seen = AnnouncementsSeen();
  // init is called from main; provider just holds the instance.
  return seen;
});

// ---------------------------------------------------------------------------
// Filtered + sorted list
// ---------------------------------------------------------------------------

/// Announcements sorted by date (newest first), pinned on top, expired removed.
final filteredAnnouncementsProvider = FutureProvider<List<Announcement>>((
  ref,
) async {
  final items = await ref.watch(announcementsProvider.future);
  final now = DateTime.now();

  // Remove expired.
  final active = items.where((a) => !a.isExpired(now)).toList();

  // Sort: pinned first, then newest createdAt first.
  active.sort((a, b) {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    final dateA = DateTime.tryParse(a.createdAt) ?? DateTime(0);
    final dateB = DateTime.tryParse(b.createdAt) ?? DateTime(0);
    return dateB.compareTo(dateA);
  });

  return active;
});

// ---------------------------------------------------------------------------
// Red-dot indicator
// ---------------------------------------------------------------------------

/// Whether there are unseen announcements.
final hasUnseenAnnouncementsProvider = FutureProvider<bool>((ref) async {
  final items = await ref.watch(filteredAnnouncementsProvider.future);
  final seen = ref.watch(announcementsSeenProvider);
  return seen.hasUnseen(items.map((a) => a.id));
});
