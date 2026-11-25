import 'package:dio/dio.dart';

import '../config/env.dart';
import '../update/stale_page_interceptor.dart';
import 'in_this_task.dart';
import 'logging_interceptor.dart';

/// Low-level HTTP client wrapper around Dio.
///
/// No authentication - used for public endpoints like guest registration.
///
/// The [dio] parameter allows injecting a pre-configured Dio instance, which
/// is used in integration tests to wire in a [MockHttpClient].
class ApiClient {
  ApiClient({String? baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
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
    _dio.httpClientAdapter = LeavesHere(_dio.httpClientAdapter);
    if (dio == null) {
      _dio.interceptors.add(StalePageInterceptor());
      if (Env.isDev) _dio.interceptors.add(LoggingInterceptor());
    }
  }

  final Dio _dio;

  Future<Response<T>> get<T>(String path) =>
      inThisTask(() => _dio.get<T>(path));

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      inThisTask(() => _dio.post<T>(path, data: data));
}
