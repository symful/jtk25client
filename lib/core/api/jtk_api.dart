/// JTK25 API client — Dio-based HTTP client with ETag caching.
///
/// Base URL is configurable via `--dart-define=API_BASE=...` at build time.
/// Falls back to the production URL if not set.
library;

import 'package:dio/dio.dart';

import '../models/announcement.dart';
import '../models/dosen.dart';
import '../models/event.dart';
import '../models/meta.dart';
import '../models/pengganti.dart';
import '../models/room.dart';
import '../models/schedule.dart';
import 'etag_interceptor.dart';

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

  /// The ETag interceptor instance, exposed for cache management.
  ETagInterceptor? get etagInterceptor {
    for (final inter in _dio.interceptors) {
      if (inter is ETagInterceptor) return inter;
    }
    return null;
  }

  static Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(ETagInterceptor());
    return dio;
  }

  /// Fetch meta info: schema version and data version.
  Future<MetaResponse> meta() async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/v1/meta');
    return MetaResponse.fromJson(resp.data!);
  }

  /// Fetch all class schedules.
  Future<SchedulesResponse> schedules() async {
    final resp = await _dio.get<Map<String, dynamic>>('/api/v1/schedules');
    return SchedulesResponse.fromJson(resp.data!);
  }

  /// Fetch pengganti (schedule overrides).
  Future<List<PenggantiEntry>> pengganti() async {
    final resp = await _dio.get<List<dynamic>>('/api/v1/pengganti');
    return (resp.data ?? [])
        .map((e) => PenggantiEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch announcements.
  Future<List<Announcement>> announcements() async {
    final resp = await _dio.get<List<dynamic>>('/api/v1/announcements');
    return (resp.data ?? [])
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch events.
  Future<List<JtkEvent>> events() async {
    final resp = await _dio.get<List<dynamic>>('/api/v1/events');
    return (resp.data ?? [])
        .map((e) => JtkEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch lecturers.
  Future<List<Dosen>> dosen() async {
    final resp = await _dio.get<List<dynamic>>('/api/v1/dosen');
    return (resp.data ?? [])
        .map((e) => Dosen.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch rooms.
  Future<List<Room>> rooms() async {
    final resp = await _dio.get<List<dynamic>>('/api/v1/rooms');
    return (resp.data ?? [])
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Close the underlying Dio client.
  void close() => _dio.close();
}
