/// Models for class schedules — mirrors server schema v2 exactly.
library;

/// Day of the week in Bahasa Indonesia.
enum Day {
  senin,
  selasa,
  rabu,
  kamis,
  jumat,
  sabtu,
  minggu;

  String get label => switch (this) {
    Day.senin => 'SENIN',
    Day.selasa => 'SELASA',
    Day.rabu => 'RABU',
    Day.kamis => 'KAMIS',
    Day.jumat => 'JUMAT',
    Day.sabtu => 'SABTU',
    Day.minggu => 'MINGGU',
  };

  static Day? fromJson(String value) {
    for (final d in values) {
      if (d.label == value) return d;
    }
    return null;
  }
}

/// Course type: TE (Teori) or PR (Praktek).
enum CourseType {
  te,
  pr;

  String get label => switch (this) {
    CourseType.te => 'TE',
    CourseType.pr => 'PR',
  };

  static CourseType? fromJson(String value) {
    for (final t in values) {
      if (t.label == value) return t;
    }
    return null;
  }
}

/// A single session/lesson within a day schedule.
class Session {
  const Session({
    required this.time,
    required this.courseCode,
    required this.courseName,
    required this.type,
    required this.lecturerCode,
    required this.lecturer,
    required this.room,
    this.mode,
  });

  /// Raw dot-time string, e.g. "07.00-07.50" or "07.00-12.20".
  final String time;

  /// Course code, e.g. "25IF2116".
  final String courseCode;

  /// Course name.
  final String courseName;

  /// TE or PR.
  final CourseType type;

  /// Comma-separated lecturer codes, e.g. "MV, LH, RA".
  final String lecturerCode;

  /// Comma-separated lecturer names.
  final String lecturer;

  /// Room identifier, e.g. "D108-Kelas".
  final String room;

  /// Offline/online mode. Null defaults to 'offline'.
  final String? mode;

  /// Split multi-lecturer code string into individual trimmed codes.
  List<String> get lecturerCodes => lecturerCode
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Split multi-lecturer name string into individual trimmed names.
  List<String> get lecturerNames => lecturer
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      time: json['time'] as String,
      courseCode: json['course_code'] as String,
      courseName: json['course_name'] as String,
      type: CourseType.fromJson(json['type'] as String) ?? CourseType.te,
      lecturerCode: json['lecturer_code'] as String,
      lecturer: json['lecturer'] as String,
      room: json['room'] as String,
      mode: json['mode'] as String?,
    );
  }

  /// Safely decode a list of [Session] from raw JSON.
  ///
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<Session> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(Session.fromJson).toList();
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'course_code': courseCode,
    'course_name': courseName,
    'type': type.label,
    'lecturer_code': lecturerCode,
    'lecturer': lecturer,
    'room': room,
    if (mode != null) 'mode': mode,
  };
}

/// A day's schedule containing multiple sessions.
class DaySchedule {
  const DaySchedule({required this.day, required this.sessions});

  final Day day;
  final List<Session> sessions;

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      day: Day.fromJson(json['day'] as String) ?? Day.senin,
      sessions: Session.listFromJson(json['sessions']),
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day.label,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };

  /// Safely decode a list of [DaySchedule] from raw JSON.
  ///
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<DaySchedule> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(DaySchedule.fromJson)
        .toList();
  }
}

/// A class's full schedule for the semester.
class ScheduleClass {
  const ScheduleClass({required this.className, required this.schedule});

  final String className;
  final List<DaySchedule> schedule;

  factory ScheduleClass.fromJson(Map<String, dynamic> json) {
    return ScheduleClass(
      className: json['class_name'] as String,
      schedule: DaySchedule.listFromJson(json['schedule']),
    );
  }

  Map<String, dynamic> toJson() => {
    'class_name': className,
    'schedule': schedule.map((d) => d.toJson()).toList(),
  };

  /// Safely decode a list of [ScheduleClass] from raw JSON.
  ///
  /// Returns `const []` if [raw] is null, not a list, or contains
  /// non-map elements (silently skipped).
  static List<ScheduleClass> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ScheduleClass.fromJson)
        .toList();
  }
}

/// Top-level schedules API response.
class SchedulesResponse {
  const SchedulesResponse({required this.semester, required this.classes});

  final String semester;
  final List<ScheduleClass> classes;

  factory SchedulesResponse.fromJson(Map<String, dynamic> json) {
    return SchedulesResponse(
      semester: json['semester'] as String,
      classes: ScheduleClass.listFromJson(json['classes']),
    );
  }
}
