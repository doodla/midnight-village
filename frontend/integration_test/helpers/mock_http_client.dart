import 'dart:async';

import 'package:dio/dio.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';

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
  /// With [timesOut], this client waits [AuthenticatedClient.timeout] for an
  /// answer as the app's own does, so a held answer that comes later times
  /// out as it would over the network (the test's teardown then runs out
  /// that wait).
  MockHttpClient({bool timesOut = false})
    : dio = Dio(
        BaseOptions(
          receiveTimeout: timesOut ? AuthenticatedClient.timeout : null,
        ),
      ) {
    dio.interceptors.add(
      _MockInterceptor(_registry, requests, _holds, _beforeAnswer),
    );
  }

  final Dio dio;

  /// Every request that reached the mock, in order (registered or not), so a
  /// test can assert what the app sent (method, path, body).
  final List<RequestOptions> requests = [];
  final Map<String, _MockResponse> _registry = {};
  final Map<String, HeldReplies> _holds = {};
  final Map<String, void Function(RequestOptions)> _beforeAnswer = {};

  /// Before each request for [method] [path] is answered, [answer] sees it
  /// and registers its answer (with [when] and [thenReturn], so the body is
  /// checked as any other): a server whose answer follows what was sent (a
  /// settings change answered with the lobby it makes).
  void answerEach({
    required String method,
    required String path,
    required void Function(RequestOptions request) answer,
  }) => _beforeAnswer['${method.toUpperCase()}:$path'] = answer;
  String? _pendingKey;

  /// From now on, requests for [method] [path] are answered only when the
  /// test releases them (in any order): a slow network, replies that cross.
  /// Each held reply is the answer registered when its request was made.
  HeldReplies hold({required String method, required String path}) =>
      _holds['${method.toUpperCase()}:$path'] = HeldReplies._();

  /// Answers [method] [path] at once again (held requests stay held).
  void stopHolding({required String method, required String path}) =>
      _holds.remove('${method.toUpperCase()}:$path');

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
    // A copy: the test may go on changing its map, and the app the one it
    // gets, without either reaching the registered answer.
    _registry[key!] = _MockResponse(
      statusCode: status,
      data: _copy(response.data),
      headers: response.headers.map,
    );
    _pendingKey = null;
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// A deep copy of a JSON-like body (maps and lists copied, the rest shared).
dynamic _copy(dynamic data) => switch (data) {
  Map() => <String, dynamic>{
    for (final e in data.entries) e.key as String: _copy(e.value),
  },
  List() => <dynamic>[for (final v in data) _copy(v)],
  _ => data,
};

/// Requests waiting for the test to answer them ([MockHttpClient.hold]).
class HeldReplies {
  HeldReplies._();

  final List<void Function()> _waiting = [];

  /// How many requests are waiting.
  int get length => _waiting.length;

  /// Answers the waiting request at [index] (0: the oldest).
  void release([int index = 0]) => _waiting.removeAt(index)();

  /// Answers every waiting request, oldest first.
  void releaseAll() {
    while (_waiting.isNotEmpty) {
      release();
    }
  }
}

class _MockResponse {
  const _MockResponse({
    required this.statusCode,
    this.data,
    this.headers = const {},
  });

  final int statusCode;
  final dynamic data;
  final Map<String, List<String>> headers;
}

class _MockInterceptor extends Interceptor {
  _MockInterceptor(
    this._registry,
    this._requests,
    this._holds,
    this._beforeAnswer,
  );

  final Map<String, _MockResponse> _registry;
  final List<RequestOptions> _requests;
  final Map<String, HeldReplies> _holds;
  final Map<String, void Function(RequestOptions)> _beforeAnswer;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _requests.add(options);
    final key = '${options.method.toUpperCase()}:${options.path}';
    try {
      _beforeAnswer[key]?.call(options);
    } catch (error, stack) {
      // The test's own stand-in threw (an answer off contract, say). That is
      // the test's failure, never a lost request the app quietly retries.
      Zone.current.handleUncaughtError(error, stack);
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: error.toString(),
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }
    final mock = _registry[key];

    if (mock != null) {
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: mock.statusCode,
        data: _copy(mock.data),
        headers: Headers.fromMap(mock.headers),
      );
      void answer() {
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
      }

      final held = _holds[key];
      if (held != null) {
        // Held past the client's wait: the request times out, as it would.
        var done = false;
        final wait = options.receiveTimeout;
        final timer = wait == null
            ? null
            : Timer(wait, () {
                if (done) return;
                done = true;
                handler.reject(
                  DioException.receiveTimeout(
                    timeout: wait,
                    requestOptions: options,
                  ),
                  true,
                );
              });
        held._waiting.add(() {
          timer?.cancel();
          if (done) return;
          done = true;
          answer();
        });
      } else {
        answer();
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
