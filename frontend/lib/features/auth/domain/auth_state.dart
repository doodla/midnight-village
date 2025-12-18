import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_state.freezed.dart';

/// Authentication state machine.
///
/// States:
/// - [AuthInitial]: App just launched, checking stored tokens
/// - [AuthLoading]: Authentication in progress
/// - [AuthAuthenticated]: User is authenticated
/// - [AuthUnauthenticated]: No valid tokens, show welcome screen
/// - [AuthError]: Authentication failed with error
@freezed
sealed class AuthState with _$AuthState {
  /// App just launched, checking stored tokens.
  const factory AuthState.initial() = AuthInitial;

  /// Authentication in progress (creating guest, refreshing token).
  const factory AuthState.loading() = AuthLoading;

  /// User is authenticated.
  const factory AuthState.authenticated(User user) = AuthAuthenticated;

  /// No valid tokens, show welcome screen.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Authentication failed with error message.
  const factory AuthState.error(String message) = AuthError;
}
