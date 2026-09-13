/// Announcements feature providers.
///
/// Depends on T8's `announcementsProvider` for data and adds:
/// - Seen-ID tracking (Hive box)
/// - Filtered / sorted list (pinned first, expired removed)
/// - Red-dot indicator
///
/// UI watches `announcementsProvider` directly for loading/error/data
/// (same pattern as schedules). Feature-local providers are thin sync
/// derivations that never fetch or parse independently.
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
// Filtered + sorted list — sync derivation
// ---------------------------------------------------------------------------

/// Announcements sorted by date (newest first), pinned on top, expired removed.
///
/// Derives from [announcementsProvider] synchronously. The UI watches
/// [announcementsProvider] directly for loading/error/data states.
final filteredAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final asyncItems = ref.watch(announcementsProvider);
  return asyncItems.when(
    loading: () => const <Announcement>[],
    error: (_, _) => const <Announcement>[],
    data: (items) {
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
    },
  );
});

// ---------------------------------------------------------------------------
// Red-dot indicator — sync derivation
// ---------------------------------------------------------------------------

/// Whether there are unseen announcements.
final hasUnseenAnnouncementsProvider = Provider<bool>((ref) {
  final items = ref.watch(filteredAnnouncementsProvider);
  final seen = ref.watch(announcementsSeenProvider);
  return seen.hasUnseen(items.map((a) => a.id));
});
