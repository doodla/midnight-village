import 'package:dio/dio.dart';

import '../config/env.dart';
import 'auth_interceptor.dart';
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
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 10),
               headers: {
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ) {
    _dio.interceptors.add(interceptor);
    if (dio == null && Env.isDev) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  final Dio _dio;

  Future<Response<T>> get<T>(String path) => _dio.get<T>(path);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {Object? data}) =>
      _dio.delete<T>(path, data: data);
}
