import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

/// Base class for API errors.
sealed class ApiException implements Exception {
  const ApiException();
}

/// Network connectivity error.
class NetworkException extends ApiException {
  const NetworkException(this.message);
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Server returned 401 Unauthorized.
class UnauthorizedException extends ApiException {
  const UnauthorizedException();

  @override
  String toString() => 'UnauthorizedException';
}

/// Server returned 404 Not Found.
class NotFoundException extends ApiException {
  const NotFoundException(this.resource);
  final String resource;

  @override
  String toString() => 'NotFoundException: $resource';
}

/// Server returned 400 with validation errors.
class ValidationException extends ApiException {
  const ValidationException(this.errors, {this.code});
  final Map<String, List<String>> errors;

  /// The refusal's machine-readable `code` (`lobby_full`, `bad_request`, ...)
  /// when the server gives one.
  final String? code;

  /// Returns the first error message for the given field, or any first error, or a fallback.
  String firstErrorFor(String field, {String fallback = 'Validation failed'}) {
    return errors[field]?.first ??
        errors['detail']?.first ??
        errors.values.expand((list) => list).firstOrNull ??
        fallback;
  }

  @override
  String toString() => 'ValidationException: $errors';
}

/// Server returned 5xx error.
class ServerException extends ApiException {
  const ServerException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'ServerException: $statusCode';
}

/// Server returned 403 Forbidden.
class ForbiddenException extends ApiException {
  const ForbiddenException();

  @override
  String toString() => 'ForbiddenException';
}

/// Server returned 429 Too Many Requests.
class RateLimitException extends ApiException {
  const RateLimitException();

  @override
  String toString() => 'RateLimitException';
}

/// Server returned another HTTP status (409 Conflict, ...). [message] is the
/// server's own when it sent one; [code] its machine-readable `code`.
class UnhandledHttpException extends ApiException {
  const UnhandledHttpException(this.statusCode, this.message, {this.code});
  final int statusCode;
  final String message;
  final String? code;

  @override
  String toString() => 'UnhandledHttpException: $statusCode - $message';
}

/// Server returned a response with unexpected structure.
class MalformedResponseException extends ApiException {
  const MalformedResponseException(this.message);
  final String message;

  @override
  String toString() => 'MalformedResponseException: $message';
}

/// Maps Dio exceptions to typed API exceptions.
ApiException mapDioException(DioException e) {
  final statusCode = e.response?.statusCode;

  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return NetworkException(e.message ?? 'Connection failed');
  }

  if (statusCode == null) {
    return NetworkException(e.message ?? 'Unknown error');
  }

  final data = e.response?.data;
  return switch (statusCode) {
    400 => ValidationException(
      parseServerErrors(data),
      code: serverErrorCode(data),
    ),
    401 => const UnauthorizedException(),
    403 => const ForbiddenException(),
    404 => NotFoundException(e.requestOptions.path),
    429 => const RateLimitException(),
    >= 500 => ServerException(statusCode),
    _ => UnhandledHttpException(
      statusCode,
      serverErrorMessage(data) ?? e.message ?? 'Unknown error',
      code: serverErrorCode(data),
    ),
  };
}

/// The `{"error": {...}}` wrapping of errors the server raises, unwrapped
/// (a Response a view returns itself is not wrapped).
Object? _unwrapped(Object? data) {
  if (data is Map &&
      data['error'] is Map &&
      (data['error'] as Map).containsKey('detail')) {
    return data['error'];
  }
  return data;
}

/// The refusal's machine-readable `code`, when the server sent one.
String? serverErrorCode(Object? data) {
  final body = _unwrapped(data);
  return body is Map && body['code'] is String ? body['code'] as String : null;
}

/// The server's message(s) in an error body, joined, or null without any.
String? serverErrorMessage(Object? data) {
  final messages = parseServerErrors(data).values.expand((m) => m);
  return messages.isEmpty ? null : messages.join(' ');
}

/// The messages in an error body the server sent, by field (`detail` for
/// a message that belongs to no field); the `{"error": {...}}` wrapping of
/// errors the server raises is unwrapped. Shared by every client.
Map<String, List<String>> parseServerErrors(dynamic data) {
  // Handle string error messages (some APIs return plain text)
  if (data is String && data.isNotEmpty) {
    return {
      'detail': [data],
    };
  }

  if (data is! Map<String, dynamic>) {
    if (data != null) {
      logger.w(
        'parseServerErrors: unexpected data type ${data.runtimeType}, preserving as detail',
      );
      return {
        'detail': [data.toString()],
      };
    }
    return {};
  }

  // An error the server raised (a serializer's validation, a parse error)
  // comes wrapped by its exception handler: {"error": {"status_code",
  // "detail": <string, list or field map>}}. A Response the view returns
  // itself is {"detail": ..., "code"?: ...}.
  final wrapped = data['error'];
  if (wrapped is Map<String, dynamic> && wrapped.containsKey('detail')) {
    final detail = wrapped['detail'];
    return parseServerErrors(
      detail is Map<String, dynamic> ? detail : {'detail': detail},
    );
  }

  final errors = <String, List<String>>{};
  data.forEach((key, value) {
    // `code` names the refusal (see [serverErrorCode]); it is not a field.
    if (key == 'code') return;
    if (value is List) {
      errors[key] = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      errors[key] = [value];
    } else {
      // Log unexpected types to help detect API contract changes
      logger.d(
        'parseServerErrors: ignoring non-string value for key "$key": $value (${value.runtimeType})',
      );
    }
  });
  return errors;
}
