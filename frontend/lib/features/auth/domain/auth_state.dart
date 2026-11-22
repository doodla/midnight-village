import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_state.freezed.dart';

/// Authentication state machine.
///
/// States:
/// - [AuthInitial]: App just launched, reading the saved account back
///   (asked again until the server answers)
/// - [AuthLoading]: Authentication in progress
/// - [AuthAuthenticated]: User is authenticated
/// - [AuthUnauthenticated]: No saved account (or the server refused it)
/// - [AuthError]: Making a guest account failed with error
@freezed
sealed class AuthState with _$AuthState {
  /// App just launched, reading the saved account back. [unanswered]: a try
  /// got no answer from the server (it is made again by itself): the
  /// account is kept, and nothing offers a new one meanwhile.
  const factory AuthState.initial({@Default(false) bool unanswered}) =
      AuthInitial;

  /// Authentication in progress (creating guest, refreshing token).
  const factory AuthState.loading() = AuthLoading;

  /// User is authenticated.
  const factory AuthState.authenticated(User user) = AuthAuthenticated;

  /// No valid tokens, show welcome screen.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Authentication failed with error message.
  const factory AuthState.error(String message) = AuthError;
}
