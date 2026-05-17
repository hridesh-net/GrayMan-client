import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'token_store.dart';

enum HttpMethod { get, post, put, delete }

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.unauthorized = false, this.cause});
  final String message;
  final int? status;
  final bool unauthorized;
  final Object? cause;

  @override
  String toString() => message;
}

/// HTTP client — mirrors APIClient.swift + src/api/apiClient.js.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _requestTimeout = Duration(seconds: 30);
  static const _resourceTimeout = Duration(seconds: 120);

  final http.Client _client = http.Client();

  /// Build URL like RN: `${APIConfig.baseURL}${path}` → `.../api/v1/auth/otp/send`.
  ///
  /// Do NOT use [Uri.resolve] here — on a base ending in `/api/v1`, resolve('auth/…')
  /// replaces the last segment and yields `/api/auth/…` (404 on every route).
  Uri uri(String path, [Map<String, String>? query]) {
    var base = ApiConfig.baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final segment = path.startsWith('/') ? path : '/$path';
    final built = Uri.parse('$base$segment');
    if (query == null || query.isEmpty) return built;
    return built.replace(queryParameters: query);
  }

  Map<String, String> _headers({required bool authenticated, bool withJsonBody = false}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (withJsonBody) h['Content-Type'] = 'application/json';
    if (authenticated) {
      final t = TokenStore.instance.token;
      if (t == null) {
        throw ApiException('You must sign in first.', unauthorized: true);
      }
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<T> request<T>(
    HttpMethod method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    required T Function(dynamic json) decode,
  }) async {
    final attempts = method == HttpMethod.get ? 2 : 1;
    Object? lastError;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await _sendOnce(method, path, query: query, body: body, authenticated: authenticated, decode: decode);
      } on ApiException {
        rethrow;
      } catch (e, st) {
        lastError = e;
        final transient = _isTransient(e);
        if (!transient || attempt >= attempts - 1) {
          throw _wrapTransport(e, st);
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    throw _wrapTransport(lastError ?? 'Network error', StackTrace.current);
  }

  Future<T> _sendOnce<T>(
    HttpMethod method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required bool authenticated,
    required T Function(dynamic json) decode,
  }) async {
    final target = uri(path, query);
    final encoded = body != null ? jsonEncode(body) : null;
    final headers = _headers(authenticated: authenticated, withJsonBody: body != null);

    late http.Response response;
    switch (method) {
      case HttpMethod.get:
        response = await _client.get(target, headers: headers).timeout(_requestTimeout);
        break;
      case HttpMethod.post:
        response = await _client.post(target, headers: headers, body: encoded).timeout(_resourceTimeout);
        break;
      case HttpMethod.put:
        response = await _client.put(target, headers: headers, body: encoded).timeout(_resourceTimeout);
        break;
      case HttpMethod.delete:
        response = await _client.delete(target, headers: headers).timeout(_requestTimeout);
        break;
    }

    if (response.statusCode == 401) {
      await TokenStore.instance.clear();
      throw ApiException(
        'Your session has expired. Please sign in again.',
        status: 401,
        unauthorized: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Server returned ${response.statusCode}: ${response.body}',
        status: response.statusCode,
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      return decode(null);
    }

    dynamic json;
    try {
      json = jsonDecode(response.body);
    } catch (e) {
      throw ApiException("Couldn't read server response: $e");
    }
    return decode(json);
  }

  Future<void> requestVoid(
    HttpMethod method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    await request<Null>(
      method,
      path,
      query: query,
      body: body,
      authenticated: authenticated,
      decode: (_) => null,
    );
  }

  /// PUT to S3 presigned URL — returns raw ETag header (quoted), like iOS ReelUploader.
  Future<String> uploadBytes(Uri url, List<int> bytes, String contentType) async {
    try {
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': contentType,
              'Content-Length': '${bytes.length}',
            },
            body: bytes,
          )
          .timeout(_resourceTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('S3 upload failed: ${response.statusCode}');
      }

      final etag = response.headers['etag'];
      if (etag == null || etag.isEmpty) {
        throw ApiException('S3 did not return ETag header');
      }
      return etag;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw _wrapTransport(e, StackTrace.current);
    }
  }

  bool _isTransient(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is http.ClientException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('host') ||
        msg.contains('timed out');
  }

  ApiException _wrapTransport(Object e, StackTrace st) {
    if (e is ApiException) return e;
    return ApiException('Network error: $e', cause: e);
  }
}

/// Decode list endpoints that may return a raw array or `{items: [...]}`.
List<dynamic> decodeList(dynamic json) {
  if (json == null) return [];
  if (json is List) return json;
  if (json is Map<String, dynamic>) {
    for (final key in ['items', 'workers', 'results', 'data']) {
      final v = json[key];
      if (v is List) return v;
    }
  }
  return [];
}
