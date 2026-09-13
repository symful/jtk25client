import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/pengganti.dart';
import 'package:jtk25_client/core/models/schedule.dart';

void main() {
  group('resolvePengganti', () {
    final defaultSessions = [
      Session(
        time: '07.00-09.30',
        courseCode: '25IF2111',
        courseName: 'Matematika Diskrit 2',
        type: CourseType.te,
        lecturerCode: 'AP',
        lecturer: 'Aprianti',
        room: 'D108-Kelas',
      ),
      Session(
        time: '10.40-12.20',
        courseCode: '25IF2110',
        courseName: 'Dasar Komunikasi',
        type: CourseType.te,
        lecturerCode: 'FI',
        lecturer: 'Fitri',
        room: 'D219-Kelas',
      ),
      Session(
        time: '13.00-16.30',
        courseCode: '25IF2114',
        courseName: 'Basis Data',
        type: CourseType.pr,
        lecturerCode: 'SW',
        lecturer: 'Sri Ratna',
        room: 'D106-Lab. SDB',
      ),
    ];

    test('returns default when no entries', () {
      final result = resolvePengganti(
        defaultSessions: defaultSessions,
        entries: [],
      );
      expect(result.length, 3);
    });

    test('replace: removes matching time, inserts pengganti', () {
      final entries = [
        PenggantiEntry(
          id: 'pg-001',
          classCode: 'D3-3A',
          date: '2026-09-15',
          kind: PenggantiKind.replace,
          sessions: [
            Session(
              time: '07.00-09.30',
              courseCode: '25IF2111',
              courseName: 'Matematika Diskrit 2 (Pengganti)',
              type: CourseType.te,
              lecturerCode: 'AP',
              lecturer: 'Aprianti',
              room: 'D112-Kelas', // moved room
            ),
          ],
        ),
      ];

      final result = resolvePengganti(
        defaultSessions: defaultSessions,
        entries: entries,
      );

      expect(result.length, 3);
      // Replacement session is appended after remaining defaults.
      expect(result[2].room, 'D112-Kelas');
      expect(result[2].courseName, contains('Pengganti'));
    });

    test('add: appends new sessions', () {
      final entries = [
        PenggantiEntry(
          id: 'pg-002',
          classCode: 'D3-3A',
          date: '2026-09-15',
          kind: PenggantiKind.add,
          sessions: [
            Session(
              time: '17.20-18.10',
              courseCode: '25IF9999',
              courseName: 'Tambahan',
              type: CourseType.te,
              lecturerCode: 'XX',
              lecturer: 'Extra',
              room: 'D101-Kelas',
            ),
          ],
        ),
      ];

      final result = resolvePengganti(
        defaultSessions: defaultSessions,
        entries: entries,
      );

      expect(result.length, 4);
      expect(result.last.courseCode, '25IF9999');
    });

    test('info: does not modify sessions', () {
      final entries = [
        PenggantiEntry(
          id: 'pg-003',
          classCode: 'D3-3A',
          date: '2026-09-15',
          kind: PenggantiKind.info,
          note: 'Libur nasional',
        ),
      ];

      final result = resolvePengganti(
        defaultSessions: defaultSessions,
        entries: entries,
      );

      expect(result.length, 3);
    });

    test(
      'two replace entries for same slot: last id wins deterministically',
      () {
        final entries = [
          PenggantiEntry(
            id: 'pg-b',
            classCode: 'D3-3A',
            date: '2026-09-15',
            kind: PenggantiKind.replace,
            sessions: [
              Session(
                time: '07.00-09.30',
                courseCode: '25IF2111',
                courseName: 'Matematika (Replace B)',
                type: CourseType.te,
                lecturerCode: 'XX',
                lecturer: 'B',
                room: 'D101-Kelas',
              ),
            ],
          ),
          PenggantiEntry(
            id: 'pg-a',
            classCode: 'D3-3A',
            date: '2026-09-15',
            kind: PenggantiKind.replace,
            sessions: [
              Session(
                time: '07.00-09.30',
                courseCode: '25IF2111',
                courseName: 'Matematika (Replace A)',
                type: CourseType.te,
                lecturerCode: 'YY',
                lecturer: 'A',
                room: 'D102-Kelas',
              ),
            ],
          ),
        ];

        final result = resolvePengganti(
          defaultSessions: defaultSessions,
          entries: entries,
        );

        // Sorted by id: pg-a then pg-b. pg-b wins (last replace).
        expect(result.length, 3);
        // pg-b replacement is appended last (after remaining defaults).
        expect(result[2].courseName, 'Matematika (Replace B)');
        expect(result[2].room, 'D101-Kelas');
      },
    );
  });

  group('PenggantiEntry.fromJson', () {
    test('parses minimal entry', () {
      final entry = PenggantiEntry.fromJson({
        'id': 'pg-001',
        'class_code': 'D3-3A',
        'date': '2026-09-15',
        'kind': 'info',
      });
      expect(entry.id, 'pg-001');
      expect(entry.classCode, 'D3-3A');
      expect(entry.kind, PenggantiKind.info);
      expect(entry.sessions, isEmpty);
    });

    test('parses replace entry with sessions', () {
      final entry = PenggantiEntry.fromJson({
        'id': 'pg-002',
        'class_code': 'D3-3A',
        'date': '2026-09-15',
        'kind': 'replace',
        'sessions': [
          {
            'time': '07.00-09.30',
            'course_code': '25IF2111',
            'course_name': 'Matematika',
            'type': 'TE',
            'lecturer_code': 'AP',
            'lecturer': 'Aprianti',
            'room': 'D108-Kelas',
          },
        ],
      });
      expect(entry.sessions.length, 1);
      expect(entry.sessions[0].courseCode, '25IF2111');
    });
  });
}
