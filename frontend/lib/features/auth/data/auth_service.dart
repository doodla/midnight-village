import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
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

      final data = response.data!;
      return (
        tokens: (
          access: data['access'] as String,
          refresh: data['refresh'] as String,
        ),
        user: User.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Refreshes access token using refresh token.
  ///
  /// Returns the new token pair on success.
  /// Throws [ApiException] on failure.
  Future<TokenPair> refreshToken(String refreshToken) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      // The refresh token is rotated: a new one comes with the access token.
      final data = response.data;
      final access = data?['access'];
      final refresh = data?['refresh'];
      if (access is! String || refresh is! String) {
        // Not the server's answer (a wifi sign-in page, a proxy): no answer
        // at all, never a refusal.
        throw const MalformedResponseException('No tokens in the refresh');
      }
      return (access: access, refresh: refresh);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
