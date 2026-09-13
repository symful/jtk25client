import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/utils/semver.dart';

void main() {
  group('semverCompare', () {
    test('1.9 < 1.10 (numeric, not lexicographic)', () {
      expect(semverCompare('1.9', '1.10'), lessThan(0));
      expect(semverCompare('1.10', '1.9'), greaterThan(0));
    });

    test('equal versions', () {
      expect(semverCompare('1.0.0', '1.0.0'), 0);
      expect(semverCompare('2.5', '2.5'), 0);
    });

    test('v prefix is stripped', () {
      expect(semverCompare('v1.2.3', '1.2.3'), 0);
      expect(semverCompare('V2.0', '2.0'), 0);
    });

    test('+build suffix is stripped', () {
      expect(semverCompare('1.2.3+build', '1.2.3'), 0);
      expect(semverCompare('1.2.3+5', '1.2.3+10'), 0);
    });

    test('v1.2.3+5 parsed correctly', () {
      expect(semverCompare('v1.2.3+5', '1.2.3'), 0);
      expect(semverCompare('v1.2.3+5', '1.2.4'), lessThan(0));
      expect(semverCompare('v1.2.3+5', '1.2.2'), greaterThan(0));
    });

    test('variable segment counts', () {
      // "1" is padded to [1,0] which equals [1,0] from "1.0"
      expect(semverCompare('1', '1.0'), 0);
      expect(semverCompare('1.0', '1.0.0'), 0);
      expect(semverCompare('1.0.1', '1.0'), greaterThan(0));
    });

    test('major version comparison', () {
      expect(semverCompare('2.0', '1.9'), greaterThan(0));
      expect(semverCompare('1.0', '2.0'), lessThan(0));
    });

    test('handles whitespace', () {
      expect(semverCompare(' 1.0 ', '1.0'), 0);
    });
  });
}
