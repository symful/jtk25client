/// Admin feature data layer — API client for admin schedule management.
///
/// Uses Dio with Bearer token auth. Token is stored in memory after login.
/// All admin endpoints are under /api/v1/admin/.
library;

import 'package:dio/dio.dart';

import '../../../core/api/jtk_api.dart';
import '../../../core/utils/debug_log.dart';

/// Auth response from POST /api/v1/admin/auth.
class AdminAuthResponse {
  const AdminAuthResponse({required this.ok, required this.scope});

  final bool ok;
  final String scope;

  factory AdminAuthResponse.fromJson(Map<String, dynamic> json) {
    return AdminAuthResponse(
      ok: json['ok'] as bool? ?? false,
      scope: json['scope'] as String? ?? '',
    );
  }
}

/// A single schedule row from the admin API (flat row with ID).
class AdminScheduleRow {
  const AdminScheduleRow({
    required this.id,
    required this.className,
    required this.semester,
    required this.day,
    required this.time,
    required this.courseCode,
    required this.courseName,
    required this.type,
    required this.lecturerCode,
    required this.lecturer,
    required this.room,
    this.slotOrder = 0,
  });

  final int id;
  final String className;
  final String semester;
  final String day;
  final String time;
  final String courseCode;
  final String courseName;
  final String type;
  final String lecturerCode;
  final String lecturer;
  final String room;
  final int slotOrder;

  /// Convert to JSON map for POST/PUT requests.
  Map<String, dynamic> toJson() => {
    'class_name': className,
    'semester': semester,
    'day': day,
    'time': time,
    'course_code': courseCode,
    'course_name': courseName,
    'type': type,
    'lecturer_code': lecturerCode,
    'lecturer': lecturer,
    'room': room,
    'slot_order': slotOrder,
  };

  factory AdminScheduleRow.fromJson(Map<String, dynamic> json) {
    return AdminScheduleRow(
      id: json['id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      day: json['day'] as String? ?? '',
      time: json['time'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      type: json['type'] as String? ?? 'TE',
      lecturerCode: json['lecturer_code'] as String? ?? '',
      lecturer: json['lecturer'] as String? ?? '',
      room: json['room'] as String? ?? '',
      slotOrder: json['slot_order'] as int? ?? 0,
    );
  }

  /// Safely decode a list of [AdminScheduleRow] from raw JSON list.
  static List<AdminScheduleRow> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AdminScheduleRow.fromJson)
        .toList();
  }
}

/// Grouped class schedule for admin display.
class AdminClassSchedule {
  const AdminClassSchedule({required this.className, required this.schedule});

  final String className;

  /// Grouped by day: list of {day, sessions}.
  final List<AdminDaySchedule> schedule;

  factory AdminClassSchedule.fromJson(Map<String, dynamic> json) {
    return AdminClassSchedule(
      className: json['class_name'] as String? ?? '',
      schedule: (json['schedule'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminDaySchedule.fromJson)
          .toList(),
    );
  }

  /// Get all class names from a list of schedules.
  static List<String> classNames(List<AdminClassSchedule> classes) {
    return classes.map((c) => c.className).toList();
  }
}

/// A single day within a class schedule.
class AdminDaySchedule {
  const AdminDaySchedule({required this.day, required this.sessions});

  final String day;
  final List<AdminScheduleSession> sessions;

  factory AdminDaySchedule.fromJson(Map<String, dynamic> json) {
    return AdminDaySchedule(
      day: json['day'] as String? ?? '',
      sessions: (json['sessions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminScheduleSession.fromJson)
          .toList(),
    );
  }
}

/// A single session within a day (from grouped response — may not have ID).
class AdminScheduleSession {
  const AdminScheduleSession({
    this.id,
    required this.time,
    required this.courseCode,
    required this.courseName,
    required this.type,
    required this.lecturerCode,
    required this.lecturer,
    required this.room,
    this.mode = 'offline',
  });

  final int? id;
  final String time;
  final String courseCode;
  final String courseName;
  final String type;
  final String lecturerCode;
  final String lecturer;
  final String room;
  final String mode;

  bool get hasId => id != null && id! > 0;

  factory AdminScheduleSession.fromJson(Map<String, dynamic> json) {
    return AdminScheduleSession(
      id: json['id'] as int?,
      time: json['time'] as String? ?? '',
      courseCode: json['course_code'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      type: json['type'] as String? ?? 'TE',
      lecturerCode: json['lecturer_code'] as String? ?? '',
      lecturer: json['lecturer'] as String? ?? '',
      room: json['room'] as String? ?? '',
      mode: json['mode'] as String? ?? 'offline',
    );
  }
}

/// Admin schedules API response (same structure as public API).
class AdminSchedulesResponse {
  const AdminSchedulesResponse({required this.semester, required this.classes});

  final String semester;
  final List<AdminClassSchedule> classes;

  factory AdminSchedulesResponse.fromJson(Map<String, dynamic> json) {
    return AdminSchedulesResponse(
      semester: json['semester'] as String? ?? '',
      classes: (json['classes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AdminClassSchedule.fromJson)
          .toList(),
    );
  }
}

/// HTTP client for the JTK25 Admin API.
///
/// Requires a Bearer token for all requests except [auth].
/// Token is stored in memory after successful [auth] call.
class AdminApi {
  AdminApi({Dio? dio, String? baseUrl})
    : _dio = dio ?? _createDio(baseUrl ?? apiBase);

  late final Dio _dio;

  /// In-memory auth token (set after successful login).
  String? _token;

  /// Current auth scope (set after successful login).
  String? get scope => _scope;
  String? _scope;

  bool get isAuthenticated => _token != null;

  static Dio _createDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  /// Set the auth token (e.g., from a stored session).
  void setToken(String token, String scope) {
    _token = token;
    _scope = scope;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear the auth token (logout).
  void clearToken() {
    _token = null;
    _scope = null;
    _dio.options.headers.remove('Authorization');
  }

  /// Authenticate with password. Returns scope on success.
  ///
  /// On success, stores the token (password itself acts as Bearer token)
  /// and sets the Authorization header.
  Future<AdminAuthResponse> auth(String password) async {
    debugLog('[AdminApi] POST /api/v1/admin/auth');
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/admin/auth',
      data: {'password': password},
    );
    final result = AdminAuthResponse.fromJson(resp.data!);
    if (result.ok) {
      setToken(password, result.scope);
    }
    return result;
  }

  /// Fetch all schedules (grouped by class and day).
  Future<AdminSchedulesResponse> getSchedules() async {
    debugLog('[AdminApi] GET /api/v1/admin/schedules');
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api/v1/admin/schedules',
    );
    return AdminSchedulesResponse.fromJson(resp.data!);
  }

  /// Fetch a single class schedule.
  Future<AdminClassSchedule?> getScheduleByClass(String className) async {
    debugLog('[AdminApi] GET /api/v1/admin/schedules/$className');
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/api/v1/admin/schedules/$className',
      );
      final data = resp.data!['data'];
      if (data is Map<String, dynamic>) {
        return AdminClassSchedule.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Add a new schedule session.
  Future<int?> addSchedule({
    required String className,
    required String semester,
    required String day,
    required String time,
    required String courseCode,
    required String courseName,
    required String type,
    required String lecturerCode,
    required String lecturer,
    required String room,
    int slotOrder = 0,
    String mode = 'offline',
  }) async {
    debugLog('[AdminApi] POST /api/v1/admin/schedules');
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/admin/schedules',
      data: {
        'class_name': className,
        'semester': semester,
        'day': day,
        'time': time,
        'course_code': courseCode,
        'course_name': courseName,
        'type': type,
        'lecturer_code': lecturerCode,
        'lecturer': lecturer,
        'room': room,
        'slot_order': slotOrder,
        'mode': mode,
      },
    );
    if (resp.data?['ok'] == true) {
      return resp.data?['id'] as int?;
    }
    return null;
  }

  /// Update an existing schedule session.
  Future<bool> updateSchedule(
    int id, {
    required String className,
    required String semester,
    required String day,
    required String time,
    required String courseCode,
    required String courseName,
    required String type,
    required String lecturerCode,
    required String lecturer,
    required String room,
    int slotOrder = 0,
    String mode = 'offline',
  }) async {
    debugLog('[AdminApi] PUT /api/v1/admin/schedules/$id');
    final resp = await _dio.put<Map<String, dynamic>>(
      '/api/v1/admin/schedules/$id',
      data: {
        'class_name': className,
        'semester': semester,
        'day': day,
        'time': time,
        'course_code': courseCode,
        'course_name': courseName,
        'type': type,
        'lecturer_code': lecturerCode,
        'lecturer': lecturer,
        'room': room,
        'slot_order': slotOrder,
        'mode': mode,
      },
    );
    return resp.data?['ok'] == true;
  }

  /// Delete a schedule session.
  Future<bool> deleteSchedule(int id) async {
    debugLog('[AdminApi] DELETE /api/v1/admin/schedules/$id');
    final resp = await _dio.delete<Map<String, dynamic>>(
      '/api/v1/admin/schedules/$id',
    );
    return resp.data?['ok'] == true;
  }

  /// Close the underlying Dio client.
  void close() => _dio.close();
}
