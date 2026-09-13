/// Regression tests for the fetch chain: cache-first, background refresh,
/// failure-keeps-cache, and stale detection.
///
/// Verifies that:
/// 1. Uninitialized cache does not crash providers (graceful no-op).
/// 2. CachedPayload.isStale correctly identifies old data.
/// 3. Uninitialized cache fallback returns null (no crash).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:jtk25_client/core/cache/offline_cache.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('fetch_chain_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });
  group('OfflineCache — uninitialized state is safe', () {
    test('save does not throw when cache is not initialized', () async {
      final cache = OfflineCache();
      // Intentionally NOT calling init().
      expect(cache.isInitialized, isFalse);

      // Should not throw.
      await cache.save(CacheKey.meta, {'schema': 2});
    });

    test('load returns null when cache is not initialized', () {
      final cache = OfflineCache();
      expect(cache.isInitialized, isFalse);
      expect(cache.load(CacheKey.meta), isNull);
    });

    test('loadJson returns null when cache is not initialized', () {
      final cache = OfflineCache();
      expect(cache.isInitialized, isFalse);
      expect(cache.loadJson(CacheKey.meta), isNull);
    });
  });

  group('CachedPayload — isStale', () {
    test('fresh payload (< 5 min) is not stale', () {
      final payload = CachedPayload(
        json: '{"key":"value"}',
        fetchedAt: DateTime.now().toUtc().toIso8601String(),
      );
      expect(payload.isStale, isFalse);
    });

    test('old payload (> 5 min) is stale', () {
      final oldTime = DateTime.now().toUtc().subtract(
        const Duration(minutes: 10),
      );
      final payload = CachedPayload(
        json: '{"key":"value"}',
        fetchedAt: oldTime.toIso8601String(),
      );
      expect(payload.isStale, isTrue);
    });

    test('exactly 5 min boundary is stale', () {
      final boundary = DateTime.now().toUtc().subtract(
        const Duration(minutes: 5, seconds: 1),
      );
      final payload = CachedPayload(
        json: '{"key":"value"}',
        fetchedAt: boundary.toIso8601String(),
      );
      expect(payload.isStale, isTrue);
    });

    test('unparseable fetchedAt is treated as stale', () {
      const payload = CachedPayload(
        json: '{"key":"value"}',
        fetchedAt: 'not-a-date',
      );
      expect(payload.isStale, isTrue);
    });
  });

  group('Fetch chain — cache-first resilience', () {
    test('uninitialized cache does not crash provider save flow', () async {
      final cache = OfflineCache();
      // NOT calling init().

      // Simulate the provider's save-then-return pattern:
      var returned = false;
      try {
        await cache.save(CacheKey.announcements, {
          'data': [
            {'id': '1'},
          ],
        });
        returned = true;
      } catch (_) {
        // Should never reach here.
      }

      expect(returned, isTrue);
    });

    test('uninitialized cache fallback returns null (no crash)', () {
      final cache = OfflineCache();
      // NOT calling init().

      // Simulate the provider's cache-fallback pattern:
      final cached = cache.loadJson(CacheKey.announcements);
      expect(cached, isNull);
    });

    test('cached data survives after network failure pattern', () async {
      final cache = OfflineCache();
      await cache.init();

      // Simulate successful fetch → cache write.
      await cache.save(CacheKey.announcements, {
        'data': [
          {'id': '1', 'title': 'Test'},
        ],
      });

      // Simulate network failure — cache should still have data.
      final cached = cache.load(CacheKey.announcements);
      expect(cached, isNotNull);
      expect(cached!.json, contains('Test'));

      // Simulate second fetch failure — cache data persists.
      final cachedAgain = cache.load(CacheKey.announcements);
      expect(cachedAgain, isNotNull);

      await cache.clearAll();
    });

    test('cache overwrite on successful refresh', () async {
      final cache = OfflineCache();
      await cache.init();

      // First fetch.
      await cache.save(CacheKey.events, {
        'data': [
          {'id': '1'},
        ],
      });

      // Background refresh with new data.
      await cache.save(CacheKey.events, {
        'data': [
          {'id': '1'},
          {'id': '2'},
        ],
      });

      final loaded = cache.loadJson(CacheKey.events);
      final data = loaded['data'] as List<dynamic>;
      expect(data.length, 2);

      await cache.clearAll();
    });
  });
}
