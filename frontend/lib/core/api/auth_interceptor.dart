import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_client.dart';

/// Dio interceptor that injects JWT bearer tokens and handles 401 responses
/// by refreshing the access token and retrying the original request.
///
/// Extends [QueuedInterceptorsWrapper] so that concurrent requests queue up
/// while a token refresh is in progress — preventing parallel refresh calls.
class AuthInterceptor extends QueuedInterceptorsWrapper {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required ApiClient unauthenticatedClient,
    required void Function() onAuthFailure,
    Future<Response<dynamic>> Function(RequestOptions)? retryFetch,
  }) : _tokenStorage = tokenStorage,
       _unauthenticatedClient = unauthenticatedClient,
       _onAuthFailure = onAuthFailure,
       _retryFetch = retryFetch ?? ((opts) => Dio().fetch<dynamic>(opts));

  final TokenStorage _tokenStorage;
  final ApiClient _unauthenticatedClient;
  final void Function() _onAuthFailure;
  final Future<Response<dynamic>> Function(RequestOptions) _retryFetch;

  /// Signs [options] with the access token held in memory and passes it on
  /// at once: nothing waits here, so a tap's request leaves in the tap's own
  /// task ([TokenStorage.held]). Only a request made before storage was ever
  /// read waits for that one read.
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    void sign(String? accessToken) {
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      handler.next(options);
    }

    final held = _tokenStorage.held;
    if (held != null) return sign(held.access);
    _tokenStorage.accessToken.then(
      sign,
      onError: (Object e, StackTrace stack) => handler.reject(
        DioException(requestOptions: options, error: e, stackTrace: stack),
      ),
    );
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Check if the access token was already refreshed by a concurrent request.
    // QueuedInterceptorsWrapper serializes interceptor calls, so when this
    // handler runs for a second queued 401, the first handler may have already
    // updated storage with a new token.
    final currentAccessToken = await _tokenStorage.accessToken;
    final requestToken = err.requestOptions.headers['Authorization'] as String?;

    if (currentAccessToken != null &&
        requestToken != 'Bearer $currentAccessToken') {
      // Another request already refreshed the token — retry with the new one.
      err.requestOptions.headers['Authorization'] =
          'Bearer $currentAccessToken';
      try {
        final response = await _retryFetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }

    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken == null) {
      _onAuthFailure();
      return handler.next(err);
    }

    try {
      final response = await _unauthenticatedClient.post<Map<String, dynamic>>(
        '/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      // The refresh token is rotated: both come back.
      final data = response.data!;
      final newAccess = data['access'] as String;
      final newRefresh = data['refresh'] as String;

      await _tokenStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _retryFetch(err.requestOptions);
      return handler.resolve(retryResponse);
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401) {
        await _tokenStorage.deleteTokens();
        _onAuthFailure();
      }
      return handler.next(err);
    } catch (_) {
      return handler.next(err);
    }
  }
}
