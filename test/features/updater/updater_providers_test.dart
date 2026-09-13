/// Regression test: UpdaterNotifier.build() must NOT read its own state.
///
/// The original crash was:
///   Bad state: Tried to read the state of an uninitialized provider
///   at UpdaterNotifier._checkForUpdate (line 94)
///   called from UpdaterNotifier.build (line 77)
///
/// `_checkForUpdate` read `state.copyWith(...)` before `build()` had returned
/// the initial state — illegal in a Riverpod Notifier.
///
/// The fix defers the check via `Future.microtask` so it runs AFTER build()
/// returns the initial state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/features/updater/data/github_releases_client.dart';
import 'package:jtk25_client/features/updater/providers/updater_providers.dart';

void main() {
  group('UpdaterNotifier initialization', () {
    test('build() returns initial UpdateState without throwing', () {
      final container = ProviderContainer();

      // This must NOT throw "Bad state: Tried to read the state of an
      // uninitialized provider".
      final state = container.read(updaterProvider);

      expect(state.release, isNull);
      expect(state.isLoading, isFalse);
      expect(state.dismissed, isFalse);
      expect(state.localVersion, isNull);

      container.dispose();
    });

    test('initial shouldShow is false', () {
      final container = ProviderContainer();
      final state = container.read(updaterProvider);

      expect(state.shouldShow, isFalse);

      container.dispose();
    });
  });

  group('UpdateState.shouldShow', () {
    test('returns false when loading', () {
      const state = UpdateState(isLoading: true);
      expect(state.shouldShow, isFalse);
    });

    test('returns false when dismissed', () {
      const state = UpdateState(dismissed: true);
      expect(state.shouldShow, isFalse);
    });

    test('returns false when release is null', () {
      const state = UpdateState();
      expect(state.shouldShow, isFalse);
    });

    test('returns false when localVersion is null', () {
      final state = UpdateState(
        release: ReleaseInfo(
          tag: 'v2.0.0',
          name: 'Release',
          body: '',
          apkDownloadUrl: 'https://example.com/app.apk',
          publishedAt: DateTime(2026, 9, 13),
        ),
      );
      expect(state.shouldShow, isFalse);
    });
  });

  group('UpdateState.copyWith', () {
    test('preserves all fields by default', () {
      const original = UpdateState(
        isLoading: true,
        dismissed: true,
        localVersion: '1.0.0',
      );
      final copy = original.copyWith();

      expect(copy.isLoading, isTrue);
      expect(copy.dismissed, isTrue);
      expect(copy.localVersion, '1.0.0');
    });

    test('clearRelease sets release to null', () {
      final state = UpdateState(
        release: ReleaseInfo(
          tag: 'v1.0.0',
          name: 'Release',
          body: '',
          publishedAt: DateTime(2026, 9, 13),
        ),
      );
      final cleared = state.copyWith(clearRelease: true);

      expect(cleared.release, isNull);
    });
  });
}
