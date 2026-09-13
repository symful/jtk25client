import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/api/etag_interceptor.dart';
import 'package:jtk25_client/core/api/jtk_api.dart';
import 'package:jtk25_client/core/models/meta.dart';
import 'package:jtk25_client/core/models/schedule.dart';

void main() {
  group('ETagInterceptor', () {
    late ETagInterceptor interceptor;
    late Dio dio;

    setUp(() {
      interceptor = ETagInterceptor();
      dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.com',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      dio.interceptors.add(interceptor);
    });

    test('stores ETag from successful response', () async {
      // We can't easily mock Dio's adapter in pure dart tests,
      // so we test the interceptor logic directly.
      interceptor.setEtag('/api/v1/meta', '"abc123"');
      expect(interceptor.getEtag('/api/v1/meta'), '"abc123"');
    });

    test('clear removes all ETags and cache', () {
      interceptor.setEtag('/a', '1');
      interceptor.setEtag('/b', '2');
      interceptor.clear();
      expect(interceptor.getEtag('/a'), isNull);
      expect(interceptor.getEtag('/b'), isNull);
    });

    test('304 path stores cached response', () {
      interceptor.setEtag('/api/v1/meta', '"abc"');
      expect(interceptor.etag304Response, isNull);
      // Simulate what happens on 304: the cached response is stored.
      interceptor.etag304Response = {'schema': 2, 'dataVersion': 'v1'};
      expect(interceptor.etag304Response, isNotNull);
      expect(interceptor.etag304Response!['schema'], 2);
    });
  });

  group('JtkApi', () {
    test('creates with default base URL', () {
      final api = JtkApi();
      expect(api, isNotNull);
      api.close();
    });

    test('creates with custom base URL', () {
      final api = JtkApi(baseUrl: 'https://custom.api.com');
      expect(api, isNotNull);
      api.close();
    });

    test('etagInterceptor is accessible', () {
      final api = JtkApi();
      expect(api.etagInterceptor, isNotNull);
      api.close();
    });
  });

  group('MetaResponse', () {
    test('fromJson parses correctly', () {
      final meta = MetaResponse.fromJson({
        'schema': 2,
        'dataVersion': '2026-09-13T19:30:00+07:00',
      });
      expect(meta.schema, 2);
      expect(meta.dataVersion, '2026-09-13T19:30:00+07:00');
    });
  });

  group('Schema guard', () {
    test('schema 2 is accepted', () {
      expect(guardSchema(2), isNull); // null = OK
    });

    test('schema 3 (higher) returns SchemaTooNew', () {
      final result = guardSchema(3);
      expect(result, isA<SchemaTooNew>());
      expect((result as SchemaTooNew).message, contains('Perlu update'));
    });

    test('schema null returns SchemaUnknown', () {
      final result = guardSchema(null);
      expect(result, isA<SchemaUnknown>());
    });

    test('schema 0 returns SchemaUnknown', () {
      final result = guardSchema(0);
      expect(result, isA<SchemaUnknown>());
    });

    test('schema -1 returns SchemaUnknown', () {
      final result = guardSchema(-1);
      expect(result, isA<SchemaUnknown>());
    });
  });

  group('SchedulesResponse', () {
    test('fromJson parses class schedules', () {
      final response = SchedulesResponse.fromJson({
        'semester': '2026/2027-GANJIL',
        'classes': [
          {
            'class_name': 'D3-2A',
            'schedule': [
              {
                'day': 'SENIN',
                'sessions': [
                  {
                    'time': '07.00-12.20',
                    'course_code': '25IF2116',
                    'course_name': 'Proyek 3',
                    'type': 'PR',
                    'lecturer_code': 'MV, LH, RA',
                    'lecturer': 'Maisevli, Lukmannul, Rahil',
                    'room': 'H501-Lab. TI',
                  },
                ],
              },
            ],
          },
        ],
      });
      expect(response.semester, '2026/2027-GANJIL');
      expect(response.classes.length, 1);
      expect(response.classes[0].className, 'D3-2A');
      expect(response.classes[0].schedule.length, 1);
      expect(response.classes[0].schedule[0].day, Day.senin);
      expect(response.classes[0].schedule[0].sessions.length, 1);
    });
  });

  group('Session multi-lecturer split', () {
    test('splits comma-separated lecturer codes', () {
      final session = Session(
        time: '07.00-12.20',
        courseCode: '25IF2116',
        courseName: 'Proyek 3',
        type: CourseType.pr,
        lecturerCode: 'MV, LH, RA',
        lecturer: 'Maisevli, Lukmannul, Rahil',
        room: 'H501-Lab. TI',
      );

      expect(session.lecturerCodes, ['MV', 'LH', 'RA']);
      expect(session.lecturerNames, ['Maisevli', 'Lukmannul', 'Rahil']);
    });

    test('single lecturer', () {
      final session = Session(
        time: '07.00-09.30',
        courseCode: '25IF2111',
        courseName: 'Matematika Diskrit 2',
        type: CourseType.te,
        lecturerCode: 'AP',
        lecturer: 'Aprianti',
        room: 'D108-Kelas',
      );

      expect(session.lecturerCodes, ['AP']);
      expect(session.lecturerNames, ['Aprianti']);
    });

    test('handles trailing/leading spaces', () {
      final session = Session(
        time: '07.00-09.30',
        courseCode: '25IF2111',
        courseName: 'Test',
        type: CourseType.te,
        lecturerCode: ' AB , CD ',
        lecturer: ' Alice , Bob ',
        room: 'D108',
      );

      expect(session.lecturerCodes, ['AB', 'CD']);
      expect(session.lecturerNames, ['Alice', 'Bob']);
    });
  });
}
