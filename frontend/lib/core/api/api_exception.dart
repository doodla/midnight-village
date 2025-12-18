import 'package:dio/dio.dart';

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

/// Maps Dio exceptions to typed API exceptions.
ApiException mapDioException(DioException e) {
  final statusCode = e.response?.statusCode;

  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return NetworkException(e.message ?? 'Connection failed');
  }

  return switch (statusCode) {
    401 => const UnauthorizedException(),
    404 => NotFoundException(e.requestOptions.path),
    400 => ValidationException(_parseValidationErrors(e.response?.data)),
    >= 500 => ServerException(statusCode!),
    _ => NetworkException(e.message ?? 'Unknown error'),
  };
}

Map<String, List<String>> _parseValidationErrors(dynamic data) {
  if (data is! Map<String, dynamic>) return {};

  final errors = <String, List<String>>{};
  data.forEach((key, value) {
    if (value is List) {
      errors[key] = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      errors[key] = [value];
    }
  });
  return errors;
}
