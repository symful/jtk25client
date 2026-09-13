/// In-app updater feature.
///
/// Polls GitHub Releases for new APK versions, compares with local semver,
/// and shows a dismissible banner + changelog dialog. Android-only.
///
/// Usage:
/// ```dart
/// // In your app shell / home page:
/// const UpdateBanner()
///
/// // Or wrap content:
/// UpdaterShell(child: MyMainContent())
/// ```
library;

export 'data/updater_data.dart';
export 'providers/updater_providers.dart';
export 'ui/updater_ui.dart';
