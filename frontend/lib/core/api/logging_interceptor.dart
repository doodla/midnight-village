import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

/// Dio interceptor that logs HTTP requests and responses.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.d('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.d('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      '✕ ${err.requestOptions.method} ${err.requestOptions.path}',
      error: err,
    );
    handler.next(err);
  }
}
