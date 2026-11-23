import 'package:dio/dio.dart';

import 'stale_smell.dart';

/// Reports a stale-build smell ([StaleSmell]) when an API call is answered
/// with a page: the web host's own HTML or its plain "not found" where the
/// server's JSON should be (a build that asks for a path the live one no
/// longer has, or a host that rewrote it). The server's own refusals are
/// JSON and smell of nothing. Changes no request and no answer.
class StalePageInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_isPage(response)) StaleSmell.report();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null && (_isPage(response) || _notJson404(response))) {
      StaleSmell.report();
    }
    handler.next(err);
  }

  static bool _isPage(Response<dynamic> response) =>
      (response.headers.value(Headers.contentTypeHeader) ?? '').contains(
        'text/html',
      );

  static bool _notJson404(Response<dynamic> response) =>
      response.statusCode == 404 &&
      !(response.headers.value(Headers.contentTypeHeader) ?? '').contains(
        'json',
      );
}
