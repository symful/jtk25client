@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

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
            'class_code': 'D3-3A',
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
          'class_name': 'D3-3A',
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
          'class_name': 'D3-3A',
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
          'class_name': 'D3-3A',
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
          'class_name': 'D3-3A',
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
        className: 'D3-3A',
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
          classCode: 'D3-3A',
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
        exportFilename(EditorDataType.schedule, classCode: 'D3-3A'),
        'schedules_D3_S3_A.json',
      );
      expect(
        exportFilename(EditorDataType.schedule, classCode: 'D4-3T-B'),
        'schedules_D4_S3T_B.json',
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
}
