import 'package:dio/dio.dart';

import 'semver.dart';

/// GitHub Releases API client for the JTK25 client repository.
///
/// Fetches the latest release from
/// `https://api.github.com/repos/symful/jtk25client/releases/latest`.
/// Public endpoint, no authentication required.
class GitHubReleasesClient {
  GitHubReleasesClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _apiBase,
              headers: {'Accept': 'application/vnd.github+json'},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  static const _apiBase = 'https://api.github.com';
  static const _owner = 'symful';
  static const _repo = 'jtk25client';

  final Dio _dio;

  /// Fetches the latest release and returns a parsed [ReleaseInfo].
  ///
  /// Returns `null` if the network call fails, the response is malformed,
  /// or the release has no usable APK asset.
  Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final resp = await _dio.get<dynamic>(
        '/repos/$_owner/$_repo/releases/latest',
      );
      if (resp.statusCode != 200) return null;
      return ReleaseInfo.fromJson(Map<String, dynamic>.from(resp.data as Map));
    } on DioException {
      // Network failure = silent no-op
      return null;
    } on FormatException {
      // Malformed JSON = silent no-op
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Parsed information from a GitHub release relevant to the updater.
class ReleaseInfo {
  /// The release tag (e.g. `"v1.2.3+5"`).
  final String tag;

  /// The release name / title.
  final String name;

  /// The release body (changelog / release notes).
  final String body;

  /// The browser download URL for the APK asset, or `null` if none exists.
  final String? apkDownloadUrl;

  /// When the release was published.
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    this.apkDownloadUrl,
    required this.publishedAt,
  });

  /// Parsed semver components from the tag.
  List<int> get version => Semver.parse(tag);

  /// Normalized version string (no `v`, no build metadata).
  String get versionString => Semver.normalize(tag);

  /// Whether this release has a downloadable APK asset.
  bool get hasApk => apkDownloadUrl != null;

  /// Factory: parse from GitHub API JSON.
  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final name = json['name'] as String? ?? tag;
    final body = json['body'] as String? ?? '';
    final publishedAt = json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : DateTime.now();

    // Find first .apk asset
    String? apkUrl;
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        final url = asset['browser_download_url'] as String? ?? '';
        if (url.toLowerCase().endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }
    }

    return ReleaseInfo(
      tag: tag,
      name: name,
      body: body,
      apkDownloadUrl: apkUrl,
      publishedAt: publishedAt,
    );
  }

  @override
  String toString() =>
      'ReleaseInfo(tag=$tag, version=$versionString, hasApk=$hasApk)';
}
