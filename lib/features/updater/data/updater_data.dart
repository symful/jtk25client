/// Updater data layer.
///
/// - [Semver] — local semver parse/compare (TODO: dedup with core/utils/semver.dart after T8)
/// - [GitHubReleasesClient] — fetches latest release from GitHub API
/// - [ReleaseInfo] — parsed release metadata
library;

export 'github_releases_client.dart';
export 'semver.dart';
