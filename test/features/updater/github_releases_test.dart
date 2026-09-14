import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/features/updater/data/github_releases_client.dart';
import 'package:jtk25_client/features/updater/data/semver.dart';

void main() {
  group('ReleaseInfo.fromJson', () {
    test('parses release with APK asset', () {
      final json = {
        'tag_name': 'v1.2.3',
        'name': 'Release 1.2.3',
        'body': 'Changelog here',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': [
          {
            'browser_download_url':
                'https://github.com/symful/jtk25client/releases/download/v1.2.3/jtk25_client-1.2.3.apk',
            'name': 'jtk25_client-1.2.3.apk',
          },
        ],
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.tag, 'v1.2.3');
      expect(release.name, 'Release 1.2.3');
      expect(release.body, 'Changelog here');
      expect(release.hasApk, isTrue);
      expect(release.apkDownloadUrl, contains('.apk'));
      expect(release.versionString, '1.2.3');
      expect(release.version, [1, 2, 3]);
    });

    test('parses release without APK asset', () {
      final json = {
        'tag_name': 'v2.0.0',
        'name': 'Release 2.0.0',
        'body': 'No binaries',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': [
          {
            'browser_download_url':
                'https://github.com/symful/jtk25client/releases/download/v2.0.0/source.zip',
            'name': 'source.zip',
          },
        ],
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.hasApk, isFalse);
      expect(release.apkDownloadUrl, isNull);
    });

    test('parses release with empty assets', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Release 1.0.0',
        'body': '',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': <dynamic>[],
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.hasApk, isFalse);
    });

    test('parses release with null assets', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Release 1.0.0',
        'body': '',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': null,
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.hasApk, isFalse);
    });

    test('parses release with missing optional fields', () {
      final json = <String, dynamic>{
        'tag_name': 'v1.0.0',
        'published_at': '2026-09-13T12:00:00Z',
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.tag, 'v1.0.0');
      expect(release.name, 'v1.0.0'); // falls back to tag
      expect(release.body, ''); // defaults to empty
      expect(release.hasApk, isFalse);
    });

    test('prefers first APK asset when multiple exist', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Release',
        'body': '',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': [
          {
            'browser_download_url': 'https://example.com/old.apk',
            'name': 'old.apk',
          },
          {
            'browser_download_url': 'https://example.com/new.apk',
            'name': 'new.apk',
          },
        ],
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.apkDownloadUrl, 'https://example.com/old.apk');
    });
  });

  group('Update guard logic (version comparison)', () {
    test('no update when remote == local (equal)', () {
      expect(Semver.isNewer('1.0.0', '1.0.0'), isFalse);
    });

    test('no update when remote < local (downgrade)', () {
      expect(Semver.isNewer('1.0.0', '2.0.0'), isFalse);
    });

    test('update when remote > local', () {
      expect(Semver.isNewer('1.1.0', '1.0.0'), isTrue);
    });

    test('update across minor versions', () {
      expect(Semver.isNewer('1.10.0', '1.9.0'), isTrue);
    });

    test('update across major versions', () {
      expect(Semver.isNewer('2.0.0', '1.99.99'), isTrue);
    });

    test('no update when versions differ only in build metadata', () {
      expect(Semver.isNewer('1.0.0+5', '1.0.0+10'), isFalse);
    });
  });

  group('Missing-asset guard', () {
    test('ReleaseInfo with no APK asset should not trigger update', () {
      final json = {
        'tag_name': 'v99.0.0',
        'name': 'Future',
        'body': '',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': <dynamic>[],
      };

      final release = ReleaseInfo.fromJson(json);

      // Even though version is higher, no APK means no update
      expect(release.hasApk, isFalse);
    });
  });

  group('Malformed-release guard', () {
    test('ReleaseInfo handles completely empty JSON gracefully', () {
      final json = <String, dynamic>{};

      // Should not throw — tag_name defaults, published_at defaults to now
      final release = ReleaseInfo.fromJson(json);

      expect(release.tag, '');
      expect(release.hasApk, isFalse);
    });

    test('ReleaseInfo handles null body gracefully', () {
      final json = {
        'tag_name': 'v1.0.0',
        'body': null,
        'published_at': '2026-09-13T12:00:00Z',
        'assets': null,
      };

      final release = ReleaseInfo.fromJson(json);

      expect(release.body, '');
      expect(release.hasApk, isFalse);
    });
  });
}
