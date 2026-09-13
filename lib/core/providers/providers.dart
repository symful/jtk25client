/// Riverpod providers for the JTK25 client data layer.
///
/// [dataVersionProvider] tracks the server's data version.
/// Per-collection providers manage each data collection with
/// network-first, cache-fallback strategy.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/jtk_api.dart';
import '../cache/offline_cache.dart';
import '../models/announcement.dart';
import '../models/dosen.dart';
import '../models/event.dart';
import '../models/meta.dart';
import '../models/pengganti.dart';
import '../models/room.dart';
import '../models/schedule.dart';

/// Singleton API client provider.
final apiClientProvider = Provider<JtkApi>((ref) {
  return JtkApi();
});

/// Singleton offline cache provider.
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  return OfflineCache();
});

class _DataVersionNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

/// The server's current dataVersion string.
final dataVersionProvider = NotifierProvider<_DataVersionNotifier, String>(
  _DataVersionNotifier.new,
);

class _SchemaVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void update(int value) => state = value;
}

/// The server's schema version.
final schemaVersionProvider = NotifierProvider<_SchemaVersionNotifier, int>(
  _SchemaVersionNotifier.new,
);

/// Simple boolean flag notifier (replaces removed StateProvider in Riverpod 3.x).
class _BoolFlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Reset the flag to false.
  void reset() => state = false;

  /// Set the flag to true.
  void markLoaded() => state = true;
}

/// Meta response provider — fetches schema + dataVersion.
final fetchMetaProvider = FutureProvider<MetaResponse>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final meta = await api.meta();
    ref.read(dataVersionProvider.notifier).update(meta.dataVersion);
    ref.read(schemaVersionProvider.notifier).update(meta.schema);

    // Cache meta (non-critical — don't let cache failure lose network data).
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.meta, {
        'schema': meta.schema,
        'dataVersion': meta.dataVersion,
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return meta;
  } on Object catch (_) {
    // Fallback to cache.
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.meta);
    if (cached is Map<String, dynamic>) {
      return MetaResponse.fromJson(cached);
    }
    rethrow;
  }
});

/// Schedules provider — fetches all class schedules.
final schedulesProvider = FutureProvider<SchedulesResponse>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final schedules = await api.schedules();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.schedules, {
        'semester': schedules.semester,
        'classes': schedules.classes.map((c) => c.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return schedules;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.schedules);
    if (cached is Map<String, dynamic>) {
      return SchedulesResponse.fromJson(cached);
    }
    rethrow;
  }
});

/// Pengganti provider — fetches schedule overrides.
final penggantiProvider = FutureProvider<List<PenggantiEntry>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final entries = await api.pengganti();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.pengganti, {
        'data': entries.map((e) => e.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return entries;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.pengganti);
    if (cached is Map<String, dynamic>) {
      final data = cached['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => PenggantiEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    rethrow;
  }
});

/// Whether announcements are loaded from Hive cache (for soft banner).
final announcementsFromCacheProvider =
    NotifierProvider<_BoolFlagNotifier, bool>(_BoolFlagNotifier.new);

/// Announcements provider.
final announcementsProvider = FutureProvider<List<Announcement>>((ref) async {
  // Reset cache flag on each fetch.
  ref.read(announcementsFromCacheProvider.notifier).reset();
  final api = ref.watch(apiClientProvider);
  try {
    final items = await api.announcements();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.announcements, {
        'data': items.map((a) => a.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return items;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.announcements);
    if (cached is Map<String, dynamic>) {
      ref.read(announcementsFromCacheProvider.notifier).markLoaded();
      final data = cached['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    rethrow;
  }
});

/// Whether events are loaded from Hive cache (for soft banner).
final eventsFromCacheProvider = NotifierProvider<_BoolFlagNotifier, bool>(
  _BoolFlagNotifier.new,
);

/// Events provider.
final eventsProvider = FutureProvider<List<JtkEvent>>((ref) async {
  // Reset cache flag on each fetch.
  ref.read(eventsFromCacheProvider.notifier).reset();
  final api = ref.watch(apiClientProvider);
  try {
    final items = await api.events();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.events, {
        'data': items.map((e) => e.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return items;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.events);
    if (cached is Map<String, dynamic>) {
      ref.read(eventsFromCacheProvider.notifier).markLoaded();
      final data = cached['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => JtkEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    rethrow;
  }
});

/// Dosen (lecturers) provider.
final dosenProvider = FutureProvider<List<Dosen>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final items = await api.dosen();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.dosen, {
        'data': items.map((d) => d.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return items;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.dosen);
    if (cached is Map<String, dynamic>) {
      final data = cached['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => Dosen.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    rethrow;
  }
});

/// Rooms provider.
final roomsProvider = FutureProvider<List<Room>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final items = await api.rooms();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.rooms, {
        'data': items.map((r) => r.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return items;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.rooms);
    if (cached is Map<String, dynamic>) {
      final data = cached['data'] as List<dynamic>? ?? [];
      return data.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
    }
    rethrow;
  }
});
