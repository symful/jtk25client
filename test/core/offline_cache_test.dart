import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/core/cache/offline_cache.dart';

void main() {
  late Directory tempDir;
  late OfflineCache cache;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('offline_cache_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    cache = OfflineCache();
    await cache.init();
  });

  tearDown(() async {
    await cache.clearAll();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('OfflineCache', () {
    test('save and load roundtrip', () async {
      final payload = {'schema': 2, 'dataVersion': 'abc123'};
      await cache.save(CacheKey.meta, payload);

      final loaded = cache.load(CacheKey.meta);
      expect(loaded, isNotNull);
      expect(loaded!.json, contains('"schema":2'));
      expect(loaded.fetchedAt, isNotEmpty);
    });

    test('loadJson returns decoded object', () async {
      final payload = {'key': 'value', 'number': 42};
      await cache.save(CacheKey.schedules, payload);

      final decoded = cache.loadJson(CacheKey.schedules);
      expect(decoded, isA<Map>());
      expect(decoded['key'], 'value');
      expect(decoded['number'], 42);
    });

    test('load returns null for empty cache', () {
      expect(cache.load(CacheKey.meta), isNull);
    });

    test('loadJson returns null for empty cache', () {
      expect(cache.loadJson(CacheKey.meta), isNull);
    });

    test('clearOne removes only that key', () async {
      await cache.save(CacheKey.meta, {'a': 1});
      await cache.save(CacheKey.schedules, {'b': 2});

      await cache.clearOne(CacheKey.meta);

      expect(cache.load(CacheKey.meta), isNull);
      expect(cache.load(CacheKey.schedules), isNotNull);
    });

    test('clearAll removes everything', () async {
      await cache.save(CacheKey.meta, {'a': 1});
      await cache.save(CacheKey.schedules, {'b': 2});
      await cache.save(CacheKey.pengganti, {'c': 3});

      await cache.clearAll();

      expect(cache.load(CacheKey.meta), isNull);
      expect(cache.load(CacheKey.schedules), isNull);
      expect(cache.load(CacheKey.pengganti), isNull);
    });

    test('save overwrites previous value', () async {
      await cache.save(CacheKey.meta, {'version': 1});
      await cache.save(CacheKey.meta, {'version': 2});

      final loaded = cache.loadJson(CacheKey.meta);
      expect(loaded['version'], 2);
    });

    test('multiple cache keys work independently', () async {
      final keys = [
        CacheKey.meta,
        CacheKey.schedules,
        CacheKey.pengganti,
        CacheKey.announcements,
        CacheKey.events,
        CacheKey.dosen,
        CacheKey.rooms,
      ];

      for (var i = 0; i < keys.length; i++) {
        await cache.save(keys[i], {'index': i});
      }

      for (var i = 0; i < keys.length; i++) {
        final loaded = cache.loadJson(keys[i]);
        expect(loaded['index'], i);
      }
    });

    test('corrupted cache entry returns null on load', () async {
      // Manually write corrupted data to the box.
      final box = await Hive.openBox<String>('jtk_meta');
      await box.put('data', '{corrupted json');

      final loaded = cache.load(CacheKey.meta);
      expect(loaded, isNull);
    });

    test('fetchedAt is ISO 8601 format', () async {
      await cache.save(CacheKey.meta, {'test': true});
      final loaded = cache.load(CacheKey.meta)!;

      // Should be parseable as DateTime
      expect(DateTime.tryParse(loaded.fetchedAt), isNotNull);
    });
  });
}
