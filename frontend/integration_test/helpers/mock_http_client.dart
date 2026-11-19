import 'dart:async';

import 'package:dio/dio.dart';

/// Thrown when a request is made to an endpoint with no registered mock response.
///
/// Includes [method] and [path] to aid debugging — you will know exactly which
/// endpoint the test forgot to stub.
class UnmockedEndpointException implements Exception {
  const UnmockedEndpointException(this.method, this.path);

  final String method;
  final String path;

  @override
  String toString() =>
      'UnmockedEndpointException: $method $path has no registered mock response';
}

/// Checks a canned response body when it is registered (see
/// [MockHttpClient.responseCheck]).
typedef ResponseCheck =
    void Function(String method, String path, int status, dynamic data);

/// A deterministic HTTP mock layer for tests.
///
/// Wraps a [Dio] instance with an interceptor that returns canned responses for
/// registered endpoints. A request with no registered response FAILS THE TEST:
/// the [UnmockedEndpointException] is reported to the test's zone as an
/// uncaught error (so the app catching the request's [DioException], as it
/// does for "best effort" calls, cannot hide it), and the request is rejected.
/// A test that expects an unmocked call must catch the report with
/// `runZonedGuarded`.
///
/// Usage:
/// ```dart
/// final client = MockHttpClient();
/// client
///   .when(method: 'GET', path: '/api/v1/me/')
///   .thenReturn(Response(
///     requestOptions: RequestOptions(path: '/api/v1/me/'),
///     statusCode: 200,
///     data: {'id': 1, 'username': 'alice'},
///   ));
///
/// final response = await client.dio.get('/api/v1/me/');
/// expect(response.data['username'], 'alice');
/// ```
///
/// Paths are matched exactly (method + path key). Register separate entries for
/// different HTTP methods on the same path:
/// ```dart
/// client.when(method: 'GET',  path: '/api/v1/games/').thenReturn(...);
/// client.when(method: 'POST', path: '/api/v1/games/').thenReturn(...);
/// ```
class MockHttpClient {
  MockHttpClient() : dio = Dio() {
    dio.interceptors.add(_MockInterceptor(_registry, requests));
  }

  final Dio dio;

  /// Every request that reached the mock, in order (registered or not), so a
  /// test can assert what the app sent (method, path, body).
  final List<RequestOptions> requests = [];
  final Map<String, _MockResponse> _registry = {};
  String? _pendingKey;

  /// Run on every body passed to [thenReturn] (unless `offContract`). The
  /// unit and widget tests set it (test/flutter_test_config.dart) to the
  /// check against the server's recorded samples; it stays unset in the web
  /// integration build, which cannot read them.
  static ResponseCheck? responseCheck;

  /// Begins registering a mock for [method] + [path].
  ///
  /// Must be followed immediately by [thenReturn].
  MockHttpClient when({required String method, required String path}) {
    _pendingKey = '${method.toUpperCase()}:$path';
    return this;
  }

  /// Completes registration by supplying the canned [response].
  ///
  /// The [response]'s [Response.statusCode] and [Response.data] are stored;
  /// [RequestOptions] are replaced at request time with the actual options.
  /// The body is checked with [responseCheck]; [offContract] skips that, for a
  /// test about a body the server would never send (malformed input).
  void thenReturn(Response<dynamic> response, {bool offContract = false}) {
    final key = _pendingKey;
    assert(key != null, 'Call when() before thenReturn()');
    final status = response.statusCode ?? 200;
    if (!offContract) {
      final split = key!.indexOf(':');
      responseCheck?.call(
        key.substring(0, split),
        key.substring(split + 1),
        status,
        response.data,
      );
    }
    _registry[key!] = _MockResponse(statusCode: status, data: response.data);
    _pendingKey = null;
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _MockResponse {
  const _MockResponse({required this.statusCode, this.data});

  final int statusCode;
  final dynamic data;
}

class _MockInterceptor extends Interceptor {
  _MockInterceptor(this._registry, this._requests);

  final Map<String, _MockResponse> _registry;
  final List<RequestOptions> _requests;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _requests.add(options);
    final key = '${options.method.toUpperCase()}:${options.path}';
    final mock = _registry[key];

    if (mock != null) {
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: mock.statusCode,
        data: mock.data,
      );
      // An error status fails the request, as it does over the network.
      if (options.validateStatus(mock.statusCode)) {
        handler.resolve(response, true);
      } else {
        handler.reject(
          DioException.badResponse(
            statusCode: mock.statusCode,
            requestOptions: options,
            response: response,
          ),
          true,
        );
      }
    } else {
      final error = UnmockedEndpointException(options.method, options.path);
      Zone.current.handleUncaughtError(error, StackTrace.current);
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: error.toString(),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}
