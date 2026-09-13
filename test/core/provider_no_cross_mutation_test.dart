/// Regression test: room occupancy helpers are pure functions.
///
/// These functions compute occupancy matrices from raw schedule data
/// without any provider context, ensuring they can be tested in isolation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jtk25_client/core/models/schedule.dart';
import 'package:jtk25_client/features/rooms/data/rooms_data.dart';

void main() {
  group('isRoomOccupiedOnDay', () {
    test('returns false when room has no sessions on given day', () {
      final classes = [
        ScheduleClass(
          className: 'D3-2A',
          schedule: [
            DaySchedule(
              day: Day.senin,
              sessions: [
                Session(
                  time: '07.00-07.50',
                  courseCode: 'TEST',
                  courseName: 'Test',
                  type: CourseType.te,
                  lecturerCode: 'XX',
                  lecturer: 'Dosen',
                  room: 'D108-Kelas',
                ),
              ],
            ),
          ],
        ),
      ];

      final matrix = buildOccupancyMatrix(classes);

      // D108 is occupied on Senin, not on Selasa.
      expect(
        isRoomOccupiedOnDay(matrix, roomId: 'D108-Kelas', day: Day.senin),
        isTrue,
      );
      expect(
        isRoomOccupiedOnDay(matrix, roomId: 'D108-Kelas', day: Day.selasa),
        isFalse,
      );
    });

    test('returns false for non-existent room', () {
      final classes = [
        ScheduleClass(
          className: 'D3-2A',
          schedule: [
            DaySchedule(
              day: Day.senin,
              sessions: [
                Session(
                  time: '07.00-07.50',
                  courseCode: 'TEST',
                  courseName: 'Test',
                  type: CourseType.te,
                  lecturerCode: 'XX',
                  lecturer: 'Dosen',
                  room: 'D108-Kelas',
                ),
              ],
            ),
          ],
        ),
      ];

      final matrix = buildOccupancyMatrix(classes);
      expect(
        isRoomOccupiedOnDay(matrix, roomId: 'NONEXISTENT', day: Day.senin),
        isFalse,
      );
    });
  });

  group('getRoomDayOccupancies', () {
    test('returns deduplicated occupancies for a room on a day', () {
      // A session spanning 07.00-08.40 occupies 2 slots — should appear once.
      final classes = [
        ScheduleClass(
          className: 'D3-2A',
          schedule: [
            DaySchedule(
              day: Day.senin,
              sessions: [
                Session(
                  time: '07.00-08.40',
                  courseCode: '25IF2111',
                  courseName: 'Matdisk',
                  type: CourseType.te,
                  lecturerCode: 'MV',
                  lecturer: 'Dosen MV',
                  room: 'D108-Kelas',
                ),
              ],
            ),
          ],
        ),
      ];

      final matrix = buildOccupancyMatrix(classes);
      final occupancies = getRoomDayOccupancies(
        matrix,
        roomId: 'D108-Kelas',
        day: Day.senin,
      );

      expect(occupancies, hasLength(1));
      expect(occupancies.first.courseCode, '25IF2111');
      expect(occupancies.first.sessionTime, '07.00-08.40');
    });

    test('returns empty list when room has no sessions on that day', () {
      final matrix = buildOccupancyMatrix([]);
      final occupancies = getRoomDayOccupancies(
        matrix,
        roomId: 'D108-Kelas',
        day: Day.senin,
      );
      expect(occupancies, isEmpty);
    });
  });
}
