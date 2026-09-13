@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/models.dart';
import 'package:jtk25_client/features/editor/editor.dart';

void main() {
  group('Editor round-trip', () {
    test('valid pengganti + schedule pass server validator', () async {
      final now = DateTime.now().toIso8601String();

      // Build valid pengganti envelope.
      final pengganti = {
        'schema': 2,
        'semester': kSemester,
        'updatedAt': now,
        'data': [
          {
            'id': 'test-pengganti-001',
            'class_code': 'D3-2A',
            'date': '2026-09-15',
            'kind': 'replace',
            'sessions': [
              {
                'time': '07.00-07.50',
                'course_code': '25IF2116',
                'course_name':
                    'Proyek 3 : Pengembangan Perangkat Lunak Berbasis Web',
                'type': 'PR',
                'lecturer_code': 'MV',
                'lecturer': 'Maisevli Harika',
                'room': 'H501-Lab. TI',
              },
            ],
          },
        ],
      };

      // Build valid schedule envelope with edited Monday slot.
      final schedule = {
        'schema': 2,
        'semester': kSemester,
        'updatedAt': now,
        'data': {
          'class_name': 'D3-2A',
          'schedule': [
            {
              'day': 'SENIN',
              'sessions': [
                {
                  'time': '07.00-07.50',
                  'course_code': '25IF2116',
                  'course_name':
                      'Proyek 3 : Pengembangan Perangkat Lunak Berbasis Web',
                  'type': 'PR',
                  'lecturer_code': 'MV, LH, RA',
                  'lecturer':
                      'Maisevli Harika, Lukmannul Hakim Firdaus, Rahil Jumiyani',
                  'room': 'H501-Lab. TI',
                },
                {
                  'time': '07.50-08.40',
                  'course_code': '25IF2112',
                  'course_name': 'Pengantar Rekayasa Perangkat Lunak',
                  'type': 'TE',
                  'lecturer_code': 'SN',
                  'lecturer': 'Santi Sundari',
                  'room': 'D112-Kelas',
                },
              ],
            },
          ],
        },
      };

      // Save to temp files.
      final tempDir = await Directory.systemTemp.createTemp('editor_test');
      try {
        final sep = Platform.pathSeparator;
        final penggantiFile = File('${tempDir.path}${sep}pengganti.json');
        await penggantiFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(pengganti),
        );

        final scheduleFile = File(
          '${tempDir.path}${sep}schedules_D3_S3_A.json',
        );
        await scheduleFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(schedule),
        );

        // Run the server CLI validator.
        final result = await Process.run('npx.cmd', [
          'tsx',
          'tools/validate.ts',
          tempDir.path,
        ], workingDirectory: r'C:\Users\user\Project\jtkjadwal\server');

        expect(
          result.exitCode,
          0,
          reason: 'Validator failed:\n${result.stdout}\n${result.stderr}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('Editor negative validation', () {
    test('colon-time input fails schema validation', () {
      final schema = JtkSchemas.scheduleClass;
      final invalidEnvelope = {
        'schema': 2,
        'semester': kSemester,
        'updatedAt': DateTime.now().toIso8601String(),
        'data': {
          'class_name': 'D3-2A',
          'schedule': [
            {
              'day': 'SENIN',
              'sessions': [
                {
                  'time': '07:00-07:50', // INVALID: colon instead of dot
                  'course_code': '25IF2116',
                  'course_name': 'Proyek 3',
                  'type': 'PR',
                  'lecturer_code': 'MV',
                  'lecturer': 'Maisevli Harika',
                  'room': 'H501-Lab. TI',
                },
              ],
            },
          ],
        },
      };

      final result = validateAgainst(invalidEnvelope, schema);
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.fieldKey.contains('time')),
        isTrue,
        reason:
            'Expected a time-related error but got: ${result.errors.map((e) => '${e.fieldKey}: ${e.message}').join(', ')}',
      );
    });

    test('empty required field fails validation', () {
      final schema = JtkSchemas.scheduleClass;
      final invalidEnvelope = {
        'schema': 2,
        'semester': kSemester,
        'updatedAt': DateTime.now().toIso8601String(),
        'data': {
          'class_name': 'D3-2A',
          'schedule': [
            {
              'day': 'SENIN',
              'sessions': [
                {
                  'time': '07.00-07.50',
                  'course_code': '', // INVALID: empty
                  'course_name': 'Proyek 3',
                  'type': 'PR',
                  'lecturer_code': 'MV',
                  'lecturer': 'Maisevli Harika',
                  'room': 'H501-Lab. TI',
                },
              ],
            },
          ],
        },
      };

      final result = validateAgainst(invalidEnvelope, schema);
      expect(result.isValid, isFalse);
    });

    test('invalid enum type fails validation', () {
      final schema = JtkSchemas.scheduleClass;
      final invalidEnvelope = {
        'schema': 2,
        'semester': kSemester,
        'updatedAt': DateTime.now().toIso8601String(),
        'data': {
          'class_name': 'D3-2A',
          'schedule': [
            {
              'day': 'SENIN',
              'sessions': [
                {
                  'time': '07.00-07.50',
                  'course_code': '25IF2116',
                  'course_name': 'Proyek 3',
                  'type': 'INVALID', // INVALID: not TE or PR
                  'lecturer_code': 'MV',
                  'lecturer': 'Maisevli Harika',
                  'room': 'H501-Lab. TI',
                },
              ],
            },
          ],
        },
      };

      final result = validateAgainst(invalidEnvelope, schema);
      expect(result.isValid, isFalse);
    });
  });

  group('Editor envelope building', () {
    test('buildScheduleEnvelope produces valid envelope', () {
      final sc = ScheduleClass(
        className: 'D3-2A',
        schedule: [
          DaySchedule(
            day: Day.senin,
            sessions: [
              const Session(
                time: '07.00-07.50',
                courseCode: '25IF2116',
                courseName: 'Proyek 3',
                type: CourseType.pr,
                lecturerCode: 'MV',
                lecturer: 'Maisevli Harika',
                room: 'H501-Lab. TI',
              ),
            ],
          ),
        ],
      );

      final envelope = buildScheduleEnvelope(sc);
      expect(envelope['schema'], 2);
      expect(envelope['semester'], kSemester);
      expect(envelope['data'], isA<Map>());

      // Validate against schema.
      final result = validateAgainst(envelope, JtkSchemas.scheduleClass);
      expect(
        result.isValid,
        isTrue,
        reason: result.errors
            .map((e) => '${e.fieldKey}: ${e.message}')
            .join(', '),
      );
    });

    test('buildPenggantiEnvelope produces valid envelope', () {
      final entries = [
        PenggantiEntry(
          id: 'test-001',
          classCode: 'D3-2A',
          date: '2026-09-15',
          kind: PenggantiKind.replace,
          sessions: [
            const Session(
              time: '07.00-07.50',
              courseCode: '25IF2116',
              courseName: 'Proyek 3',
              type: CourseType.pr,
              lecturerCode: 'MV',
              lecturer: 'Maisevli Harika',
              room: 'H501-Lab. TI',
            ),
          ],
        ),
      ];

      final envelope = buildPenggantiEnvelope(entries);
      expect(envelope['schema'], 2);
      expect(envelope['data'], isA<List>());

      final result = validateAgainst(envelope, JtkSchemas.pengganti);
      expect(
        result.isValid,
        isTrue,
        reason: result.errors
            .map((e) => '${e.fieldKey}: ${e.message}')
            .join(', '),
      );
    });
  });

  group('Editor filename generation', () {
    test('exportFilename returns correct names', () {
      expect(
        exportFilename(EditorDataType.schedule, classCode: 'D3-2A'),
        'schedules_D3_S3_A.json',
      );
      expect(
        exportFilename(EditorDataType.schedule, classCode: 'D4-2B'),
        'schedules_D4_S3_B.json',
      );
      expect(exportFilename(EditorDataType.pengganti), 'pengganti.json');
      expect(
        exportFilename(EditorDataType.announcements),
        'announcements.json',
      );
      expect(exportFilename(EditorDataType.events), 'events.json');
      expect(exportFilename(EditorDataType.dosen), 'dosen.json');
      expect(exportFilename(EditorDataType.rooms), 'rooms.json');
    });
  });

  group('Editor PR instructions', () {
    test('generatePrInstructions produces Bahasa text', () {
      final instructions = generatePrInstructions('pengganti.json');
      expect(instructions, contains('Fork repository'));
      expect(instructions, contains('symful/jtk25server'));
      expect(instructions, contains('pengganti'));
    });
  });

  group('Unified editor file list', () {
    test('kAllEditorFiles has exactly 11 entries', () {
      expect(kAllEditorFiles.length, 11);
    });

    test('all 6 schedule files have classCode', () {
      final scheduleFiles = kAllEditorFiles.where(
        (f) => f.type == EditorDataType.schedule,
      );
      expect(scheduleFiles.length, 6);
      for (final file in scheduleFiles) {
        expect(file.classCode, isNotNull);
      }
    });

    test('non-schedule files have null classCode', () {
      final nonSchedule = kAllEditorFiles.where(
        (f) => f.type != EditorDataType.schedule,
      );
      for (final file in nonSchedule) {
        expect(file.classCode, isNull);
      }
    });

    test('all file labels are unique', () {
      final labels = kAllEditorFiles.map((f) => f.label).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('covers all data types', () {
      final types = kAllEditorFiles.map((f) => f.type).toSet();
      expect(types, containsAll(EditorDataType.values));
    });
  });

  // -------------------------------------------------------------------------
  // CRUD provider tests (announcements, rooms, schedule)
  // -------------------------------------------------------------------------

  group('Announcements CRUD', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('add() appends a new announcement', () {
      expect(container.read(announcementsFormProvider), isEmpty);
      container.read(announcementsFormProvider.notifier).add();
      final items = container.read(announcementsFormProvider);
      expect(items.length, 1);
      expect(items.first.title, '');
      expect(items.first.body, '');
    });

    test('update() modifies an existing announcement', () {
      container.read(announcementsFormProvider.notifier).add();
      final updated = Announcement(
        id: 'test-id',
        title: 'Judul Baru',
        body: 'Isi pengumuman',
        pinned: true,
        createdAt: DateTime.now().toIso8601String(),
      );
      container.read(announcementsFormProvider.notifier).update(0, updated);
      final items = container.read(announcementsFormProvider);
      expect(items.first.title, 'Judul Baru');
      expect(items.first.body, 'Isi pengumuman');
      expect(items.first.pinned, isTrue);
    });

    test('remove() deletes an announcement by index', () {
      container.read(announcementsFormProvider.notifier).add();
      container.read(announcementsFormProvider.notifier).add();
      expect(container.read(announcementsFormProvider).length, 2);

      container.read(announcementsFormProvider.notifier).remove(0);
      final items = container.read(announcementsFormProvider);
      expect(items.length, 1);
    });

    test('remove() on last item leaves empty list', () {
      container.read(announcementsFormProvider.notifier).add();
      container.read(announcementsFormProvider.notifier).remove(0);
      expect(container.read(announcementsFormProvider), isEmpty);
    });

    test('export envelope reflects post-CRUD state', () {
      container.read(announcementsFormProvider.notifier).add();
      container.read(announcementsFormProvider.notifier).add();
      container.read(announcementsFormProvider.notifier).remove(0);

      final items = container.read(announcementsFormProvider);
      expect(items.length, 1);

      final envelope = buildAnnouncementsEnvelope(items);
      expect(envelope['schema'], 2);
      expect((envelope['data'] as List).length, 1);
    });
  });

  group('Rooms CRUD', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('add() appends a new room', () {
      expect(container.read(roomsFormProvider), isEmpty);
      container.read(roomsFormProvider.notifier).add();
      final items = container.read(roomsFormProvider);
      expect(items.length, 1);
      expect(items.first.id, '');
      expect(items.first.name, '');
    });

    test('update() modifies an existing room', () {
      container.read(roomsFormProvider.notifier).add();
      final updated = Room(
        id: 'H501',
        name: 'Lab TI',
        type: RoomType.fromJson('lab'),
      );
      container.read(roomsFormProvider.notifier).update(0, updated);
      final items = container.read(roomsFormProvider);
      expect(items.first.id, 'H501');
      expect(items.first.name, 'Lab TI');
      expect(items.first.type?.label, 'lab');
    });

    test('remove() deletes a room by index', () {
      container.read(roomsFormProvider.notifier).add();
      container.read(roomsFormProvider.notifier).add();
      expect(container.read(roomsFormProvider).length, 2);

      container.read(roomsFormProvider.notifier).remove(1);
      final items = container.read(roomsFormProvider);
      expect(items.length, 1);
    });

    test('remove() on last item leaves empty list', () {
      container.read(roomsFormProvider.notifier).add();
      container.read(roomsFormProvider.notifier).remove(0);
      expect(container.read(roomsFormProvider), isEmpty);
    });

    test('export envelope reflects post-CRUD state', () {
      container.read(roomsFormProvider.notifier).add();
      container.read(roomsFormProvider.notifier).add();
      container.read(roomsFormProvider.notifier).add();
      container.read(roomsFormProvider.notifier).remove(1);

      final items = container.read(roomsFormProvider);
      expect(items.length, 2);

      final envelope = buildRoomsEnvelope(items);
      expect(envelope['schema'], 2);
      expect((envelope['data'] as List).length, 2);
    });
  });

  group('Schedule CRUD (D3-2A, SENIN)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      container.read(scheduleFormProvider.notifier).selectClass('D3-2A');
    });

    tearDown(() {
      container.dispose();
    });

    test('addSession() appends a new session to SENIN', () {
      final before = container.read(scheduleFormProvider).days['SENIN']!;
      expect(before, isEmpty);

      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      final after = container.read(scheduleFormProvider).days['SENIN']!;
      expect(after.length, 1);
    });

    test('updateSession() modifies fields on an existing session', () {
      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      final updated = SessionForm(
        time: '08.00-08.50',
        courseCode: '25IF2116',
        courseName: 'Proyek 3',
        type: 'PR',
        lecturerCode: 'MV',
        lecturer: 'Maisevli Harika',
        room: 'H501-Lab. TI',
      );
      container
          .read(scheduleFormProvider.notifier)
          .updateSession('SENIN', 0, updated);

      final session = container.read(scheduleFormProvider).days['SENIN']!.first;
      expect(session.time, '08.00-08.50');
      expect(session.courseCode, '25IF2116');
      expect(session.lecturer, 'Maisevli Harika');
    });

    test('removeSession() deletes a session by index', () {
      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      expect(container.read(scheduleFormProvider).days['SENIN']!.length, 2);

      container.read(scheduleFormProvider.notifier).removeSession('SENIN', 0);
      final sessions = container.read(scheduleFormProvider).days['SENIN']!;
      expect(sessions.length, 1);
    });

    test('removeSession() on last item leaves empty day', () {
      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      container.read(scheduleFormProvider.notifier).removeSession('SENIN', 0);
      expect(container.read(scheduleFormProvider).days['SENIN'], isEmpty);
    });

    test('loadFromClass() loads existing data then add/edit/remove work', () {
      final sc = ScheduleClass(
        className: 'D3-2A',
        schedule: [
          DaySchedule(
            day: Day.senin,
            sessions: [
              const Session(
                time: '07.00-07.50',
                courseCode: '25IF2116',
                courseName: 'Proyek 3',
                type: CourseType.pr,
                lecturerCode: 'MV',
                lecturer: 'Maisevli Harika',
                room: 'H501-Lab. TI',
              ),
            ],
          ),
        ],
      );

      container.read(scheduleFormProvider.notifier).loadFromClass(sc);
      expect(container.read(scheduleFormProvider).days['SENIN']!.length, 1);

      // Edit
      final edited = SessionForm.fromSession(
        const Session(
          time: '07.00-07.50',
          courseCode: '25IF9999',
          courseName: 'Edited Course',
          type: CourseType.te,
          lecturerCode: 'XX',
          lecturer: 'New Lecturer',
          room: 'A101',
        ),
      );
      container
          .read(scheduleFormProvider.notifier)
          .updateSession('SENIN', 0, edited);

      final session = container.read(scheduleFormProvider).days['SENIN']!.first;
      expect(session.courseCode, '25IF9999');
      expect(session.courseName, 'Edited Course');

      // Add
      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      expect(container.read(scheduleFormProvider).days['SENIN']!.length, 2);

      // Remove
      container.read(scheduleFormProvider.notifier).removeSession('SENIN', 0);
      expect(container.read(scheduleFormProvider).days['SENIN']!.length, 1);
    });

    test('export envelope reflects post-CRUD state', () {
      container.read(scheduleFormProvider.notifier).addSession('SENIN');
      final edited = SessionForm(
        time: '07.00-07.50',
        courseCode: '25IF2116',
        courseName: 'Proyek 3',
        type: 'PR',
        lecturerCode: 'MV',
        lecturer: 'Maisevli Harika',
        room: 'H501-Lab. TI',
      );
      container
          .read(scheduleFormProvider.notifier)
          .updateSession('SENIN', 0, edited);
      container.read(scheduleFormProvider.notifier).removeSession('SENIN', 0);

      // Empty state should still produce valid envelope
      final envelope = container.read(scheduleFormProvider).toEnvelope();
      expect(envelope['schema'], 2);

      final result = validateAgainst(envelope, JtkSchemas.scheduleClass);
      expect(
        result.isValid,
        isTrue,
        reason: result.errors
            .map((e) => '${e.fieldKey}: ${e.message}')
            .join(', '),
      );
    });
  });
}
