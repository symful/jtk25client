/// Announcements feature data layer — unseen-ID persistence.
///
/// Tracks which announcement IDs the user has already seen,
/// used to power the red-dot indicator on the list.
library;

import 'package:hive_ce/hive.dart';

/// Hive box name for unseen announcement IDs.
const String _boxName = 'jtk_announcements_seen';

/// Manager for marking announcements as seen.
class AnnouncementsSeen {
  AnnouncementsSeen({HiveInterface? hive}) : _hive = hive;

  final HiveInterface? _hive;
  HiveInterface get _h => _hive ?? Hive;

  Box<String>? _box;

  Future<void> init() async {
    _box ??= await _h.openBox<String>(_boxName);
  }

  /// All IDs the user has already seen.
  Set<String> get seenIds {
    if (_box == null) return const {};
    return _box!.keys.cast<String>().toSet();
  }

  /// Whether [id] has been seen.
  bool hasSeen(String id) {
    if (_box == null) return false;
    return _box!.containsKey(id);
  }

  /// Mark a single ID as seen.
  Future<void> markSeen(String id) async {
    if (_box == null) return;
    await _box!.put(id, DateTime.now().toUtc().toIso8601String());
  }

  /// Mark multiple IDs as seen.
  Future<void> markAllSeen(Iterable<String> ids) async {
    if (_box == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final id in ids) {
      await _box!.put(id, now);
    }
  }

  /// Whether there are any unseen IDs in [allIds].
  bool hasUnseen(Iterable<String> allIds) {
    if (_box == null) return false;
    return allIds.any((id) => !_box!.containsKey(id));
  }

  /// Clear all seen records.
  Future<void> clearAll() async => _box?.clear();
}
