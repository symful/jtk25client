/// Offline cache backed by Hive CE boxes.
///
/// Stores last-good payload + fetchedAt per endpoint.
/// Used as fallback when network requests fail.
library;

import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// Cached payload for a single endpoint.
class CachedPayload {
  const CachedPayload({required this.json, required this.fetchedAt});

  /// The raw JSON string of the last successful response.
  final String json;

  /// ISO 8601 timestamp of when this payload was fetched.
  final String fetchedAt;

  /// Whether this payload is older than 5 minutes (stale but still usable).
  bool get isStale {
    final fetched = DateTime.tryParse(fetchedAt);
    if (fetched == null) return true;
    return DateTime.now().toUtc().difference(fetched) >
        const Duration(minutes: 5);
  }

  Map<String, dynamic> toMap() => {'json': json, 'fetchedAt': fetchedAt};

  factory CachedPayload.fromMap(Map<String, dynamic> map) {
    return CachedPayload(
      json: map['json'] as String,
      fetchedAt: map['fetchedAt'] as String,
    );
  }
}

/// Endpoint keys for the offline cache.
enum CacheKey {
  meta('jtk_meta'),
  schedules('jtk_schedules'),
  pengganti('jtk_pengganti'),
  announcements('jtk_announcements'),
  events('jtk_events'),
  dosen('jtk_dosen'),
  rooms('jtk_rooms');

  const CacheKey(this.boxKey);
  final String boxKey;
}

/// Offline cache manager using Hive boxes.
///
/// Each endpoint gets its own box storing the last-good JSON payload
/// and the fetch timestamp. Providers fall back to cache on network failure.
class OfflineCache {
  OfflineCache({HiveInterface? hive}) : _hive = hive;

  final HiveInterface? _hive;
  HiveInterface get _h => _hive ?? Hive;

  bool _initialized = false;
  final Map<String, Box<String>> _boxes = {};

  /// Initialize all cache boxes. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;
    for (final key in CacheKey.values) {
      _boxes[key.boxKey] = await _h.openBox<String>(key.boxKey);
    }
    _initialized = true;
  }

  /// Whether the cache boxes have been opened.
  bool get isInitialized => _initialized;

  /// Save a payload for the given [key].
  ///
  /// Returns silently if the cache is not yet initialized.
  Future<void> save(CacheKey key, Map<String, dynamic> payload) async {
    final box = _getBox(key);
    if (box == null) return; // Graceful no-op when uninitialized.
    final entry = CachedPayload(
      json: jsonEncode(payload),
      fetchedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await box.put('data', jsonEncode(entry.toMap()));
  }

  /// Load the cached payload for [key], or null if not cached.
  ///
  /// Returns null if the cache is not yet initialized.
  CachedPayload? load(CacheKey key) {
    final box = _getBox(key);
    if (box == null) return null;
    final raw = box.get('data');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CachedPayload.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse and return the cached JSON payload as a decoded object.
  ///
  /// Returns null if the cache is not yet initialized.
  dynamic loadJson(CacheKey key) {
    final cached = load(key);
    if (cached == null) return null;
    try {
      return jsonDecode(cached.json);
    } catch (_) {
      return null;
    }
  }

  /// Clear the cache for a single [key].
  Future<void> clearOne(CacheKey key) async {
    final box = _getBox(key);
    await box?.clear();
  }

  /// Clear all cached data.
  Future<void> clearAll() async {
    for (final key in CacheKey.values) {
      await clearOne(key);
    }
  }

  /// Returns the Hive box for [key], or null if cache is not initialized.
  Box<String>? _getBox(CacheKey key) => _boxes[key.boxKey];
}
