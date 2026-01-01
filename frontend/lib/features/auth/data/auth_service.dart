import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/user.dart';

/// Token pair returned from authentication endpoints.
typedef TokenPair = ({String access, String refresh});

/// Authentication response containing tokens and user info.
typedef AuthResponse = ({TokenPair tokens, User user});

/// Service for authentication API calls.
class AuthService {
  AuthService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// Creates a guest account.
  ///
  /// [displayName] is optional - server generates one if not provided.
  /// Returns tokens and user info on success.
  /// Throws [ApiException] on failure.
  Future<AuthResponse> createGuest({String? displayName}) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null && displayName.trim().isNotEmpty) {
        body['display_name'] = displayName.trim();
      }

      final response = await _client.post<Map<String, dynamic>>(
        '/auth/guest/',
        data: body,
      );

      final data = response.data;
      if (data == null) {
        throw const MalformedResponseException('Response body is null');
      }

      final access = data['access'];
      final refresh = data['refresh'];
      final user = data['user'];

      if (access is! String || refresh is! String) {
        throw const MalformedResponseException(
          'Missing or invalid token fields in response',
        );
      }

      if (user is! Map<String, dynamic>) {
        throw const MalformedResponseException(
          'Missing or invalid user field in response',
        );
      }

      // Parse user separately to narrow the catch scope
      final User parsedUser;
      try {
        parsedUser = User.fromJson(user);
      } on ArgumentError catch (e) {
        throw MalformedResponseException('Invalid user data: $e');
      } on TypeError catch (e) {
        throw MalformedResponseException('Invalid user data types: $e');
      }

      return (
        tokens: (access: access, refresh: refresh),
        user: parsedUser,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Refreshes access token using refresh token.
  ///
  /// Returns new token pair on success.
  /// Throws [ApiException] on failure.
  Future<TokenPair> refreshToken(String refreshToken) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      final data = response.data;
      if (data == null) {
        throw const MalformedResponseException('Response body is null');
      }

      final access = data['access'];
      if (access is! String) {
        throw const MalformedResponseException(
          'Missing or invalid access token in response',
        );
      }

      // Refresh token may or may not be returned - use original if not
      final refresh = data['refresh'];
      final newRefreshToken = refresh is String ? refresh : refreshToken;
      if (refresh is! String) {
        logger.d('AuthService.refreshToken: API did not return new refresh token, reusing original');
      }
      return (access: access, refresh: newRefreshToken);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
