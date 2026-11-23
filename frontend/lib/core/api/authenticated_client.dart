import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../requests/player_request.dart';
import 'auth_interceptor.dart';
import '../update/stale_page_interceptor.dart';
import 'logging_interceptor.dart';

/// Authenticated HTTP client that injects JWT tokens on every request.
///
/// Wraps [Dio] with an [AuthInterceptor] attached. Use this client for all
/// endpoints that require authentication. Unauthenticated endpoints (e.g. guest
/// registration, token refresh) should use the plain [ApiClient] instead.
class AuthenticatedClient {
  AuthenticatedClient({
    required String baseUrl,
    required AuthInterceptor interceptor,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: timeout,
               receiveTimeout: timeout,
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ) {
    _dio.interceptors.add(interceptor);
    if (dio == null) {
      _dio.interceptors.add(StalePageInterceptor());
      if (Env.isDev) _dio.interceptors.add(LoggingInterceptor());
    }
  }

  /// Test-only constructor that accepts a pre-configured [Dio] without
  /// requiring an [AuthInterceptor]. The caller is responsible for
  /// setting up any interceptors on [dio].
  @visibleForTesting
  AuthenticatedClient.forTesting({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// How long a request waits to connect, and for its answer.
  static const timeout = Duration(seconds: 10);

  Future<Response<T>> get<T>(String path) => _dio.get<T>(path);

  /// The writes take the [Door] (`core/requests/player_request.dart`): the
  /// one door every request a player's tap makes goes through.
  Future<Response<T>> post<T>(Door door, String path, {Object? data}) {
    door.require('POST $path');
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(Door door, String path, {Object? data}) {
    door.require('PATCH $path');
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(Door door, String path, {Object? data}) {
    door.require('DELETE $path');
    return _dio.delete<T>(path, data: data);
  }
}
