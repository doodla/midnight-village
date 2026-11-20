// The mock HTTP client lives under integration_test/helpers/ so that the web
// integration build (flutter drive), whose app root is integration_test/, can
// import it; a relative import out of that root does not compile. Unit and
// widget tests import it from here.
import 'package:dio/dio.dart';

import '../../integration_test/helpers/mock_http_client.dart';

export '../../integration_test/helpers/mock_http_client.dart';

/// Shorthand for registering a canned answer.
extension MockHttpAnswer on MockHttpClient {
  /// Answers [method] [path] with [data] and [status]. [offContract] is for a
  /// test about a body the server would never send (see
  /// [MockHttpClient.thenReturn]).
  void answer(
    String method,
    String path,
    dynamic data, {
    int status = 200,
    bool offContract = false,
  }) => when(method: method, path: path).thenReturn(
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
      data: data,
    ),
    offContract: offContract,
  );
}
