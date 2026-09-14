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
import '../models/calendar.dart';
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

class _FcTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final scheduleTriggerProvider = NotifierProvider<_FcTriggerNotifier, int>(
  _FcTriggerNotifier.new,
);
final calendarTriggerProvider = NotifierProvider<_FcTriggerNotifier, int>(
  _FcTriggerNotifier.new,
);
final penggantiTriggerProvider = NotifierProvider<_FcTriggerNotifier, int>(
  _FcTriggerNotifier.new,
);

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
///
/// Automatically re-fetches when [scheduleUpdateTriggerProvider] changes
/// (i.e. when an FCM `schedule_update` notification arrives).
final schedulesProvider = FutureProvider<SchedulesResponse>((ref) async {
  ref.watch(scheduleTriggerProvider);
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
  ref.watch(penggantiTriggerProvider);
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
      return PenggantiEntry.listFromJson(cached['data']);
    }
    rethrow;
  }
});

/// Announcements provider.
final announcementsProvider = FutureProvider<List<Announcement>>((ref) async {
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
      return Announcement.listFromJson(cached['data']);
    }
    rethrow;
  }
});

/// Calendar provider.
final calendarProvider = FutureProvider<List<JtkCalendar>>((ref) async {
  ref.watch(calendarTriggerProvider);
  final api = ref.watch(apiClientProvider);
  try {
    final items = await api.calendar();
    try {
      final cache = ref.read(offlineCacheProvider);
      await cache.save(CacheKey.calendar, {
        'data': items.map((e) => e.toJson()).toList(),
      });
    } catch (_) {
      // Cache write failed; network data is still valid.
    }
    return items;
  } on Object catch (_) {
    final cache = ref.read(offlineCacheProvider);
    final cached = cache.loadJson(CacheKey.calendar);
    if (cached is Map<String, dynamic>) {
      return JtkCalendar.listFromJson(cached['data']);
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
      return Dosen.listFromJson(cached['data']);
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
      return Room.listFromJson(cached['data']);
    }
    rethrow;
  }
});
