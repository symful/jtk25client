/// JTK25 API client — plain Dio GETs with no conditional caching.
///
/// Base URL is configurable via `--dart-define=API_BASE=...` at build time.
/// Falls back to the production URL if not set.
library;

import 'package:dio/dio.dart';

import '../models/announcement.dart';
import '../models/dosen.dart';
import '../models/calendar.dart';
import '../models/meta.dart';
import '../models/pengganti.dart';
import '../models/room.dart';
import '../models/schedule.dart';
import '../utils/debug_log.dart';

/// Production API base URL (fallback when no --dart-define is provided).
/// Uses the custom domain jtk25.my.id.
const String _defaultApiBase = 'https://jtk25.my.id';

/// The API base URL, resolved from dart-define or fallback.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: _defaultApiBase,
);

/// HTTP client for the JTK25 API.
///
/// All methods return parsed model objects. Network failures are thrown
/// as [DioException] for the caller to handle (e.g., fall back to cache).
class JtkApi {
  JtkApi({Dio? dio, String? baseUrl})
    : _dio = dio ?? _createDio(baseUrl ?? apiBase);

  late final Dio _dio;

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

  /// Fetch meta info: schema version and data version.
  Future<MetaResponse> meta() async {
    debugLog('[JtkApi] GET /api/v1/meta');
    final resp = await _dio.get<Map<String, dynamic>>('/api/v1/meta');
    return MetaResponse.fromJson(resp.data!);
  }

  /// Fetch all class schedules.
  Future<SchedulesResponse> schedules() async {
    debugLog('[JtkApi] GET /api/v1/schedules');
    final resp = await _dio.get<Map<String, dynamic>>('/api/v1/schedules');
    return SchedulesResponse.fromJson(resp.data!);
  }

  /// Fetch pengganti (schedule overrides).
  Future<List<PenggantiEntry>> pengganti() async {
    debugLog('[JtkApi] GET /api/v1/pengganti');
    final resp = await _dio.get<dynamic>('/api/v1/pengganti');
    return PenggantiEntry.listFromJson(resp.data);
  }

  /// Fetch announcements.
  Future<List<Announcement>> announcements() async {
    debugLog('[JtkApi] GET /api/v1/announcements');
    final resp = await _dio.get<dynamic>('/api/v1/announcements');
    return Announcement.listFromJson(resp.data);
  }

  /// Fetch calendar events.
  Future<List<JtkCalendar>> calendar() async {
    debugLog('[JtkApi] GET /api/v1/calendar');
    final resp = await _dio.get<dynamic>('/api/v1/calendar');
    return JtkCalendar.listFromJson(resp.data);
  }

  /// Fetch lecturers.
  Future<List<Dosen>> dosen() async {
    debugLog('[JtkApi] GET /api/v1/dosen');
    final resp = await _dio.get<dynamic>('/api/v1/dosen');
    return Dosen.listFromJson(resp.data);
  }

  /// Fetch rooms.
  Future<List<Room>> rooms() async {
    debugLog('[JtkApi] GET /api/v1/rooms');
    final resp = await _dio.get<dynamic>('/api/v1/rooms');
    return Room.listFromJson(resp.data);
  }

  /// Close the underlying Dio client.
  void close() => _dio.close();
}
