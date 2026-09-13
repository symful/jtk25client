/// ETag-based HTTP caching interceptor for Dio.
///
/// Stores ETag per endpoint, sends If-None-Match on subsequent requests,
/// and treats 304 Not Modified as a cache hit.
library;

import 'dart:io';

import 'package:dio/dio.dart';

/// A Dio interceptor that implements ETag-based conditional requests.
///
/// On a successful response with an ETag header, the interceptor stores
/// the ETag keyed by endpoint. On the next request to the same endpoint,
/// it attaches an If-None-Match header. A 304 response is converted
/// into a special [DioException] with type [DioExceptionType.connectionTimeout]
/// and the caller should check for [etag304Response].
class ETagInterceptor extends Interceptor {
  /// Internal ETag storage keyed by request path.
  final Map<String, String> _etags = {};

  /// In-memory cache of the last successful response body per endpoint.
  final Map<String, dynamic> _cachedResponses = {};

  /// The response that caused a 304 Not Modified.
  ///
  /// After handling a 304, the caller can retrieve the cached body from here.
  Map<String, dynamic>? etag304Response;

  /// Get the stored ETag for [path].
  String? getEtag(String path) => _etags[path];

  /// Store an ETag for [path].
  void setEtag(String path, String etag) => _etags[path] = etag;

  /// Get the cached response body for [path].
  dynamic getCachedBody(String path) => _cachedResponses[path];

  /// Clear all stored ETags and cached responses.
  void clear() {
    _etags.clear();
    _cachedResponses.clear();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    final etag = _etags[path];
    if (etag != null) {
      options.headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final path = response.requestOptions.path;
    final statusCode = response.statusCode;

    // Store ETag from successful response.
    final etag = response.headers.value(HttpHeaders.etagHeader);
    if (etag != null && statusCode == HttpStatus.ok) {
      _etags[path] = etag;
    }

    // Cache response body for successful responses.
    if (statusCode == HttpStatus.ok && response.data is Map) {
      _cachedResponses[path] = response.data;
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == HttpStatus.notModified) {
      // 304 Not Modified — caller should use cached data.
      etag304Response = _cachedResponses[err.requestOptions.path];
      handler.next(err);
    } else {
      handler.next(err);
    }
  }
}
