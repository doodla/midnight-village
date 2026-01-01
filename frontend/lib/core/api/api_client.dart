import 'package:dio/dio.dart';

import '../config/env.dart';
import 'logging_interceptor.dart';

/// Low-level HTTP client wrapper around Dio.
///
/// No authentication - used for public endpoints like guest registration.
class ApiClient {
  ApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? Env.apiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    if (Env.isDev) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  final Dio _dio;

  Future<Response<T>> get<T>(String path) => _dio.get<T>(path);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);
}
