import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/features/updater/data/semver.dart';

void main() {
  group('Semver.parse', () {
    test('parses basic version', () {
      expect(Semver.parse('1.0.0'), [1, 0, 0]);
    });

    test('parses version with leading v', () {
      expect(Semver.parse('v1.2.3'), [1, 2, 3]);
    });

    test('parses version with leading V', () {
      expect(Semver.parse('V2.0.0'), [2, 0, 0]);
    });

    test('strips build metadata after +', () {
      expect(Semver.parse('v1.2.3+5'), [1, 2, 3]);
    });

    test('parses double-digit components', () {
      expect(Semver.parse('1.10.0'), [1, 10, 0]);
    });

    test('parses triple-digit components', () {
      expect(Semver.parse('10.20.30'), [10, 20, 30]);
    });

    test('throws FormatException for two-part version', () {
      expect(() => Semver.parse('1.0'), throwsFormatException);
    });

    test('throws FormatException for non-numeric parts', () {
      expect(() => Semver.parse('1.abc.0'), throwsFormatException);
    });
  });

  group('Semver.compare', () {
    test('1.9.0 < 1.10.0 (minor version comparison)', () {
      expect(Semver.compare('1.9.0', '1.10.0'), lessThan(0));
    });

    test('1.10.0 > 1.9.0 (reverse)', () {
      expect(Semver.compare('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('2.0.0 < 2.0.1 (patch comparison)', () {
      expect(Semver.compare('2.0.0', '2.0.1'), lessThan(0));
    });

    test('2.0.1 > 2.0.0 (reverse)', () {
      expect(Semver.compare('2.0.1', '2.0.0'), greaterThan(0));
    });

    test('equal versions', () {
      expect(Semver.compare('1.0.0', '1.0.0'), 0);
    });

    test('downgrade: 2.0.0 vs 1.0.0', () {
      expect(Semver.compare('2.0.0', '1.0.0'), greaterThan(0));
    });

    test('downgrade: 1.0.0 vs 2.0.0', () {
      expect(Semver.compare('1.0.0', '2.0.0'), lessThan(0));
    });

    test('major version comparison', () {
      expect(Semver.compare('1.0.0', '2.0.0'), lessThan(0));
      expect(Semver.compare('2.0.0', '1.0.0'), greaterThan(0));
    });

    test('handles v prefix in comparison', () {
      expect(Semver.compare('v1.0.0', '1.0.0'), 0);
      expect(Semver.compare('v2.0.0', 'v1.0.0'), greaterThan(0));
    });

    test('handles build metadata in comparison', () {
      expect(Semver.compare('1.0.0+5', '1.0.0+10'), 0);
      expect(Semver.compare('1.0.1+1', '1.0.0+99'), greaterThan(0));
    });
  });

  group('Semver.isNewer', () {
    test('newer version detected', () {
      expect(Semver.isNewer('1.1.0', '1.0.0'), isTrue);
    });

    test('same version is not newer', () {
      expect(Semver.isNewer('1.0.0', '1.0.0'), isFalse);
    });

    test('downgrade is not newer', () {
      expect(Semver.isNewer('1.0.0', '2.0.0'), isFalse);
    });
  });

  group('Semver.normalize', () {
    test('normalizes v-prefixed tag', () {
      expect(Semver.normalize('v1.2.3'), '1.2.3');
    });

    test('normalizes tag with build metadata', () {
      expect(Semver.normalize('v1.2.3+5'), '1.2.3');
    });

    test('normalizes plain version', () {
      expect(Semver.normalize('1.0.0'), '1.0.0');
    });

    test('normalizes uppercase V', () {
      expect(Semver.normalize('V2.1.0'), '2.1.0');
    });

    test('normalizes complex tag', () {
      expect(Semver.normalize('v1.10.25+123'), '1.10.25');
    });
  });
}
