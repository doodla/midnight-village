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

/// A deterministic HTTP mock layer for tests.
///
/// Wraps a [Dio] instance with an interceptor that returns canned responses for
/// registered endpoints and throws [UnmockedEndpointException] (wrapped in a
/// [DioException]) for any unregistered request — failing loud rather than
/// silently returning empty data.
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
  void thenReturn(Response<dynamic> response) {
    assert(_pendingKey != null, 'Call when() before thenReturn()');
    _registry[_pendingKey!] = _MockResponse(
      statusCode: response.statusCode ?? 200,
      data: response.data,
    );
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
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: mock.statusCode,
          data: mock.data,
        ),
        true,
      );
    } else {
      final error = UnmockedEndpointException(options.method, options.path);
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
