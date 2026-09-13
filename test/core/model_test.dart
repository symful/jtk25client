import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/announcement.dart';
import 'package:jtk25_client/core/models/dosen.dart';
import 'package:jtk25_client/core/models/event.dart';
import 'package:jtk25_client/core/models/room.dart';

void main() {
  group('Announcement', () {
    test('fromJson parses correctly', () {
      final ann = Announcement.fromJson({
        'id': 'ann-001',
        'title': 'Selamat Datang',
        'body': 'Selamat datang kembali',
        'pinned': true,
        'createdAt': '2026-09-01T07:00:00+07:00',
        'expiresAt': '2026-12-31T23:59:59+07:00',
      });
      expect(ann.id, 'ann-001');
      expect(ann.pinned, isTrue);
      expect(ann.expiresAt, isNotNull);
    });

    test('fromJson with defaults', () {
      final ann = Announcement.fromJson({
        'id': 'ann-002',
        'title': 'Test',
        'body': 'Body',
        'createdAt': '2026-09-01T07:00:00+07:00',
      });
      expect(ann.pinned, isFalse);
      expect(ann.expiresAt, isNull);
    });

    test('isExpired returns false when no expiresAt', () {
      final ann = Announcement.fromJson({
        'id': 'ann-002',
        'title': 'Test',
        'body': 'Body',
        'createdAt': '2026-09-01T07:00:00+07:00',
      });
      expect(ann.isExpired(DateTime(2027)), isFalse);
    });

    test('isExpired returns true after expiry', () {
      final ann = Announcement.fromJson({
        'id': 'ann-002',
        'title': 'Test',
        'body': 'Body',
        'createdAt': '2026-09-01T07:00:00+07:00',
        'expiresAt': '2026-12-31T23:59:59+07:00',
      });
      expect(ann.isExpired(DateTime(2027, 1, 2)), isTrue);
    });

    test('toJson roundtrip', () {
      final ann = Announcement.fromJson({
        'id': 'ann-001',
        'title': 'Title',
        'body': 'Body',
        'pinned': true,
        'createdAt': '2026-09-01T07:00:00+07:00',
        'expiresAt': '2026-12-31T23:59:59+07:00',
      });
      final json = ann.toJson();
      final ann2 = Announcement.fromJson(json);
      expect(ann2.id, ann.id);
      expect(ann2.pinned, ann.pinned);
    });
  });

  group('Dosen', () {
    test('fromJson parses correctly', () {
      final d = Dosen.fromJson({
        'code': 'AD',
        'name': 'Dr. Ade Chandra Nugraha, S.Si., M.T.',
      });
      expect(d.code, 'AD');
      expect(d.email, isNull);
    });

    test('fromJson with email', () {
      final d = Dosen.fromJson({
        'code': 'AP',
        'name': 'Aprianti Nanda Sari',
        'email': 'aprianti@polban.ac.id',
      });
      expect(d.email, 'aprianti@polban.ac.id');
    });
  });

  group('JtkEvent', () {
    test('fromJson parses correctly', () {
      final e = JtkEvent.fromJson({
        'id': 'evt-001',
        'title': 'Kuliah Perdana',
        'description': 'Kuliah perdana',
        'date': '2026-09-01T07:00:00+07:00',
        'endDate': '2026-09-01T18:00:00+07:00',
        'location': 'Gedung JTK',
        'category': 'Akademik',
      });
      expect(e.id, 'evt-001');
      expect(e.description, isNotNull);
      expect(e.location, 'Gedung JTK');
    });

    test('fromJson with minimal fields', () {
      final e = JtkEvent.fromJson({
        'id': 'evt-002',
        'title': 'Test',
        'date': '2026-09-01T07:00:00+07:00',
        'endDate': '2026-09-01T18:00:00+07:00',
      });
      expect(e.description, isNull);
      expect(e.location, isNull);
      expect(e.category, isNull);
    });
  });

  group('Room', () {
    test('fromJson parses correctly', () {
      final r = Room.fromJson({
        'id': 'D108-Kelas',
        'name': 'D108 Kelas',
        'type': 'kelas',
      });
      expect(r.id, 'D108-Kelas');
      expect(r.type, RoomType.kelas);
    });

    test('fromJson with lab type', () {
      final r = Room.fromJson({
        'id': 'H501-Lab. TI',
        'name': 'H501 Lab. TI',
        'type': 'lab',
      });
      expect(r.type, RoomType.lab);
    });

    test('fromJson without type', () {
      final r = Room.fromJson({'id': 'D101', 'name': 'D101'});
      expect(r.type, isNull);
    });
  });
}
