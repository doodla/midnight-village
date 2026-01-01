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
  const ValidationException(this.errors);
  final Map<String, List<String>> errors;

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

/// Server returned an unhandled HTTP status code.
class UnhandledHttpException extends ApiException {
  const UnhandledHttpException(this.statusCode, this.message);
  final int statusCode;
  final String message;

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

  return switch (statusCode) {
    400 => ValidationException(_parseValidationErrors(e.response?.data)),
    401 => const UnauthorizedException(),
    403 => const ForbiddenException(),
    404 => NotFoundException(e.requestOptions.path),
    429 => const RateLimitException(),
    >= 500 => ServerException(statusCode),
    _ => UnhandledHttpException(statusCode, e.message ?? 'Unknown error'),
  };
}

Map<String, List<String>> _parseValidationErrors(dynamic data) {
  // Handle string error messages (some APIs return plain text)
  if (data is String && data.isNotEmpty) {
    return {'detail': [data]};
  }

  if (data is! Map<String, dynamic>) {
    if (data != null) {
      logger.w('_parseValidationErrors: unexpected data type ${data.runtimeType}, preserving as detail');
      return {'detail': [data.toString()]};
    }
    return {};
  }

  final errors = <String, List<String>>{};
  data.forEach((key, value) {
    if (value is List) {
      errors[key] = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      errors[key] = [value];
    } else {
      // Log unexpected types to help detect API contract changes
      logger.d('_parseValidationErrors: ignoring non-string value for key "$key": $value (${value.runtimeType})');
    }
  });
  return errors;
}
