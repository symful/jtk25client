import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/github_releases_client.dart';
import '../data/semver.dart';

/// State of the update check.
class UpdateState {
  /// The latest release info, or `null` if no update available / check pending.
  final ReleaseInfo? release;

  /// Whether the check is currently in progress.
  final bool isLoading;

  /// Whether the user has dismissed the update prompt for this release.
  final bool dismissed;

  /// The local app version (cached after first check).
  final String? localVersion;

  const UpdateState({
    this.release,
    this.isLoading = false,
    this.dismissed = false,
    this.localVersion,
  });

  UpdateState copyWith({
    ReleaseInfo? release,
    bool? isLoading,
    bool? dismissed,
    String? localVersion,
    bool clearRelease = false,
  }) {
    return UpdateState(
      release: clearRelease ? null : (release ?? this.release),
      isLoading: isLoading ?? this.isLoading,
      dismissed: dismissed ?? this.dismissed,
      localVersion: localVersion ?? this.localVersion,
    );
  }

  /// Whether the update banner/dialog should be shown.
  ///
  /// Shows only when:
  /// - We have a release with an APK asset
  /// - The remote version is newer than the local version
  /// - The user hasn't dismissed it this session
  /// - We're not currently loading
  bool get shouldShow {
    if (isLoading) return false;
    if (dismissed) return false;
    if (release == null) return false;
    if (!release!.hasApk) return false;
    if (localVersion == null) return false;
    return Semver.isNewer(release!.versionString, localVersion!);
  }
}

/// Riverpod provider that checks for app updates on launch.
///
/// Android-only: no-op on non-Android platforms.
/// Polls GitHub Releases API, compares with local pubspec version,
/// and surfaces an update if available.
final updaterProvider = NotifierProvider<UpdaterNotifier, UpdateState>(
  UpdaterNotifier.new,
);

/// Notifier that manages update-check state.
class UpdaterNotifier extends Notifier<UpdateState> {
  final _client = GitHubReleasesClient();

  @override
  UpdateState build() {
    // Trigger the check on first build (app launch).
    _checkForUpdate();
    return const UpdateState();
  }

  /// Checks GitHub Releases for a newer version.
  ///
  /// Guards:
  /// - Android-only (no-op on other platforms)
  /// - No prompt on downgrade/equal version
  /// - Silent no-op when release has no .apk asset
  /// - Network failure = silent
  Future<void> _checkForUpdate() async {
    // Android-only guard
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final localVersion = await _getAppVersion();

      final release = await _client.fetchLatestRelease();

      if (release == null) {
        // Network failure or malformed response = silent no-op
        state = state.copyWith(
          isLoading: false,
          clearRelease: true,
          localVersion: localVersion,
        );
        return;
      }

      // Guard: no .apk asset → silent no-op
      if (!release.hasApk) {
        state = state.copyWith(
          isLoading: false,
          clearRelease: true,
          localVersion: localVersion,
        );
        return;
      }

      // Guard: no downgrade or equal
      if (!Semver.isNewer(release.versionString, localVersion)) {
        state = state.copyWith(
          isLoading: false,
          clearRelease: true,
          localVersion: localVersion,
        );
        return;
      }

      // Update available!
      state = state.copyWith(
        release: release,
        isLoading: false,
        localVersion: localVersion,
      );
    } catch (_) {
      // Any unexpected error = silent no-op
      state = state.copyWith(isLoading: false, clearRelease: true);
    }
  }

  /// Dismisses the update prompt for this session.
  void dismiss() {
    state = state.copyWith(dismissed: true);
  }

  /// Manually triggers a re-check (e.g. from pull-to-refresh).
  Future<void> refresh() async {
    await _checkForUpdate();
  }
}

/// Reads the current app version from package_info.
Future<String> _getAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}
