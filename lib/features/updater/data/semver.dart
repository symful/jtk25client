/// Semantic version helper for comparing app versions.
///
/// This is a LOCAL copy kept in `features/updater/data/` to avoid depending
/// on `lib/core/utils/semver.dart` which T8 may create in parallel.
/// TODO(dedup): Once T8 lands `lib/core/utils/semver.dart`, migrate this file
/// to re-export from core and remove the local implementation.
class Semver {
  Semver._();

  /// Parses a tag or version string into `[major, minor, patch]`.
  ///
  /// Handles formats:
  /// - `"1.0.0"` → [1, 0, 0]
  /// - `"v1.2.3"` → [1, 2, 3]
  /// - `"v1.2.3+5"` → [1, 2, 3]  (build metadata stripped)
  /// - `"1.10.0"` → [1, 10, 0]
  static List<int> parse(String input) {
    // Strip leading 'v'
    var s = input.trimLeft();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    // Strip build metadata after '+'
    if (s.contains('+')) {
      s = s.split('+').first;
    }
    final parts = s.split('.');
    if (parts.length < 3) {
      throw FormatException('Invalid semver: $input');
    }
    return [int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])];
  }

  /// Normalizes a release tag to a clean version string (no `v`, no build meta).
  ///
  /// `"v1.2.3+5"` → `"1.2.3"`, `"1.0.0"` → `"1.0.0"`.
  static String normalize(String tag) {
    final v = parse(tag);
    return '${v[0]}.${v[1]}.${v[2]}';
  }

  /// Compares two version strings.
  ///
  /// Returns:
  /// - negative if `a < b`
  /// - 0 if `a == b`
  /// - positive if `a > b`
  static int compare(String a, String b) {
    final va = parse(a);
    final vb = parse(b);
    for (var i = 0; i < 3; i++) {
      if (va[i] != vb[i]) return va[i] - vb[i];
    }
    return 0;
  }

  /// Returns true if [remote] is strictly newer than [local].
  static bool isNewer(String remote, String local) =>
      compare(remote, local) > 0;
}
