import 'dart:async';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';

import '../api/api_exception.dart';

/// Thrown when a debug request returns 401. The debug client NEVER refreshes —
/// a 401 means the explicit per-player token is wrong, which is a harness bug
/// we want surfaced loudly, not silently papered over by a token rotation.
class DebugAuthException implements Exception {
  const DebugAuthException(this.path);
  final String path;

  @override
  String toString() =>
      'DebugAuthException: 401 on $path (debug client never refreshes — '
      'the per-player Bearer token is wrong)';
}

/// DEBUG-ONLY HTTP/WS client (contract §D2).
///
/// Issues REST with an EXPLICIT `Authorization: Bearer <token>` per call and
/// attaches NO [AuthInterceptor]. This is deliberate: the production
/// interceptor would, on a 401, refresh against the GLOBAL [TokenStorage] and
/// cross-contaminate identities (the harness drives many players concurrently).
/// Instead this client fails loudly on 401.
///
/// Also opens authenticated WebSockets with the required `Origin` header
/// (channels' `OriginValidator` 403s a handshake with no Origin; `dart:io`
/// does not send one by default).
class DebugApiClient {
  DebugApiClient({required String baseUrl, required this.origin, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              // Never throw on status: we inspect codes ourselves so 401 fails
              // loudly and an opted-in 409 (idempotent re-action) can pass.
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  /// The `Origin` header value for WebSocket handshakes (e.g.
  /// `http://127.0.0.1:8001`). REST does not need it, but the WS handshake does.
  final String origin;

  /// GET with an explicit bearer token. Returns the decoded JSON map.
  Future<Map<String, dynamic>> get(String path, {required String token}) async {
    final response = await _dio.get<dynamic>(path, options: _options(token));
    return _decode(response, path);
  }

  /// POST with an explicit bearer token. Returns the decoded JSON map (or {}).
  ///
  /// Set [idempotent409] only for endpoints where a 409 means "already done"
  /// (re-submitting a night action / a vote). Every other endpoint's 409 is a
  /// real conflict and must surface.
  Future<Map<String, dynamic>> post(
    String path, {
    required String token,
    Object? data,
    bool idempotent409 = false,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: data,
      options: _options(token),
    );
    return _decode(response, path, idempotent409: idempotent409);
  }

  /// PATCH with an explicit bearer token. Returns the decoded JSON map.
  Future<Map<String, dynamic>> patch(
    String path, {
    required String token,
    Object? data,
  }) async {
    final response = await _dio.patch<dynamic>(
      path,
      data: data,
      options: _options(token),
    );
    return _decode(response, path);
  }

  /// Builds per-call options. An EMPTY [token] means "send no `Authorization`
  /// header" — the unauthenticated path (e.g. `POST /auth/guest/`). A header of
  /// `Bearer ` with no token is NOT the same as omitting it: the JWT auth
  /// middleware rejects a malformed `Bearer ` before any AllowAny view runs,
  /// returning 401 ("Authorization header must contain two space-delimited
  /// values"). Omitting the header lets the guest endpoint accept the request.
  Options _options(String token) => Options(
    headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
  );

  Map<String, dynamic> _decode(
    Response<dynamic> response,
    String path, {
    bool idempotent409 = false,
  }) {
    final status = response.statusCode ?? 0;

    // 409 = idempotent re-action (already acted / already voted) — treat as OK
    // ONLY where the caller opted in. Any other 409 (e.g. lobby already started,
    // duplicate join) is a real conflict and must fail loudly below.
    if (status == 409 && idempotent409) return const {};

    if (status == 401) {
      throw DebugAuthException(path);
    }
    if (status < 200 || status >= 300) {
      throw _httpError(status, path, response.data);
    }

    final data = response.data;
    if (data == null || data == '') return const {};
    if (data is Map<String, dynamic>) return data;
    throw MalformedResponseException(
      'Expected JSON object from $path, got ${data.runtimeType}',
    );
  }

  ApiException _httpError(int status, String path, dynamic data) {
    final detail = serverErrorMessage(data) ?? '';
    return switch (status) {
      400 => ValidationException(
        parseServerErrors(data),
        code: serverErrorCode(data),
      ),
      403 => const ForbiddenException(),
      404 => NotFoundException(path),
      429 => const RateLimitException(),
      >= 500 => ServerException(status),
      _ => UnhandledHttpException(status, '$path: $detail'),
    };
  }

  /// Opens an authenticated WebSocket to [wsUrl] (e.g.
  /// `ws://127.0.0.1:8001/ws/game/<id>/`) with [token] appended as a query
  /// param and the required `Origin` header set.
  ///
  /// Used by the harness's connection helpers when it needs a raw socket
  /// for a player that is NOT the visible perspective.
  IOWebSocketChannel connectWebSocket(String wsUrl, {required String token}) {
    final base = Uri.parse(wsUrl);
    final params = Map<String, String>.from(base.queryParameters)
      ..['token'] = token;
    final uri = base.replace(queryParameters: params);
    // `Origin` is required: channels' OriginValidator 403s a handshake with no
    // Origin, and dart:io does not send one. There is no HttpHeaders constant
    // for it, so use the literal header name.
    return IOWebSocketChannel.connect(uri, headers: {'Origin': origin});
  }
}
