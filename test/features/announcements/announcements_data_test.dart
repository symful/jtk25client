import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/features/announcements/data/announcements_data.dart';

void main() {
  group('AnnouncementsSeen', () {
    test('hasSeen returns false when uninitialized (no throw)', () {
      final seen = AnnouncementsSeen();
      expect(seen.hasSeen('any-id'), isFalse);
    });

    test('seenIds returns empty set when uninitialized', () {
      final seen = AnnouncementsSeen();
      expect(seen.seenIds, isEmpty);
    });

    test('hasUnseen returns false when uninitialized', () {
      final seen = AnnouncementsSeen();
      expect(seen.hasUnseen(['a', 'b', 'c']), isFalse);
    });

    test('markSeen is no-op when uninitialized', () async {
      final seen = AnnouncementsSeen();
      // Should not throw.
      await seen.markSeen('any-id');
      expect(seen.hasSeen('any-id'), isFalse);
    });

    test('markAllSeen is no-op when uninitialized', () async {
      final seen = AnnouncementsSeen();
      await seen.markAllSeen(['a', 'b']);
      expect(seen.seenIds, isEmpty);
    });

    test('clearAll is no-op when uninitialized', () async {
      final seen = AnnouncementsSeen();
      await seen.clearAll();
      expect(seen.seenIds, isEmpty);
    });
  });
}
