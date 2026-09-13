/// Semantic version comparison utility.
///
/// Handles optional `v` prefix and `+build` suffix.
/// Examples: "1.9" < "1.10", "v1.2.3+5" parsed correctly.
library;

/// Compare two semver-like strings.
///
/// Returns:
/// - negative if [a] < [b]
/// - 0 if equal
/// - positive if [a] > [b]
///
/// Handles:
/// - Optional `v` prefix ("v1.2" → [1, 2])
/// - Optional `+build` suffix ("1.2.3+build" → [1, 2, 3])
/// - Variable segment counts ("1" < "1.0" < "1.0.1")
/// - Numeric comparison only ("1.10" > "1.9")
int semverCompare(String a, String b) {
  final pa = _parseSemver(a);
  final pb = _parseSemver(b);

  final maxLen = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < maxLen; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

/// Parse a semver string into a list of integers.
///
/// Strips optional `v` prefix and `+build` suffix.
/// Each segment is parsed as int; non-numeric segments become 0.
List<int> _parseSemver(String version) {
  var v = version.trim();

  // Strip `v` prefix.
  if (v.startsWith('v') || v.startsWith('V')) {
    v = v.substring(1);
  }

  // Strip `+build` suffix.
  final plusIndex = v.indexOf('+');
  if (plusIndex >= 0) {
    v = v.substring(0, plusIndex);
  }

  // Split on `.` and parse each segment.
  return v.split('.').map((segment) => int.tryParse(segment) ?? 0).toList();
}
