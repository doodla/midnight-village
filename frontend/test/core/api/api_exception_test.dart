import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';

void main() {
  group('ApiException types', () {
    test('ForbiddenException toString', () {
      const exception = ForbiddenException();
      expect(exception.toString(), 'ForbiddenException');
    });

    test('RateLimitException toString', () {
      const exception = RateLimitException();
      expect(exception.toString(), 'RateLimitException');
    });

    test('UnhandledHttpException toString', () {
      const exception = UnhandledHttpException(418, 'I am a teapot');
      expect(
        exception.toString(),
        'UnhandledHttpException: 418 - I am a teapot',
      );
      expect(exception.statusCode, 418);
      expect(exception.message, 'I am a teapot');
    });

    test('MalformedResponseException toString', () {
      const exception = MalformedResponseException('Missing field: foo');
      expect(
        exception.toString(),
        'MalformedResponseException: Missing field: foo',
      );
      expect(exception.message, 'Missing field: foo');
    });
  });

  group('ValidationException.firstErrorFor', () {
    test('returns error for specified field when present', () {
      const exception = ValidationException({
        'display_name': ['Name is too short', 'Name contains invalid chars'],
        'email': ['Email is required'],
      });

      expect(exception.firstErrorFor('display_name'), 'Name is too short');
    });

    test('returns detail error when field not present but detail exists', () {
      const exception = ValidationException({
        'detail': ['Authentication failed'],
      });

      expect(exception.firstErrorFor('email'), 'Authentication failed');
    });

    test('returns first available error when field and detail not present', () {
      const exception = ValidationException({
        'password': ['Password too weak'],
      });

      expect(exception.firstErrorFor('email'), 'Password too weak');
    });

    test('returns fallback when no errors present', () {
      const exception = ValidationException({});

      expect(exception.firstErrorFor('email'), 'Validation failed');
    });

    test('returns custom fallback when provided', () {
      const exception = ValidationException({});

      expect(
        exception.firstErrorFor('email', fallback: 'Custom error'),
        'Custom error',
      );
    });

    test('prefers specified field over detail', () {
      const exception = ValidationException({
        'email': ['Invalid email format'],
        'detail': ['General error'],
      });

      expect(exception.firstErrorFor('email'), 'Invalid email format');
    });
  });

  group('mapDioException', () {
    RequestOptions createRequestOptions([String path = '/test']) {
      return RequestOptions(path: path);
    }

    DioException createDioException({
      int? statusCode,
      dynamic data,
      DioExceptionType type = DioExceptionType.badResponse,
      String? message,
    }) {
      return DioException(
        requestOptions: createRequestOptions(),
        response: statusCode != null
            ? Response(
                requestOptions: createRequestOptions(),
                statusCode: statusCode,
                data: data,
              )
            : null,
        type: type,
        message: message,
      );
    }

    test('maps connection error to NetworkException', () {
      final exception = mapDioException(
        createDioException(
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ),
      );

      expect(exception, isA<NetworkException>());
      expect((exception as NetworkException).message, 'Connection refused');
    });

    test('maps connection timeout to NetworkException', () {
      final exception = mapDioException(
        createDioException(
          type: DioExceptionType.connectionTimeout,
          message: 'Timed out',
        ),
      );

      expect(exception, isA<NetworkException>());
    });

    test('maps null statusCode to NetworkException', () {
      final exception = mapDioException(
        createDioException(type: DioExceptionType.unknown),
      );

      expect(exception, isA<NetworkException>());
    });

    test('maps 400 to ValidationException', () {
      final exception = mapDioException(
        createDioException(
          statusCode: 400,
          data: {
            'email': ['Invalid'],
          },
        ),
      );

      expect(exception, isA<ValidationException>());
      expect((exception as ValidationException).errors['email'], ['Invalid']);
    });

    test('maps 401 to UnauthorizedException', () {
      final exception = mapDioException(createDioException(statusCode: 401));

      expect(exception, isA<UnauthorizedException>());
    });

    test('maps 403 to ForbiddenException', () {
      final exception = mapDioException(createDioException(statusCode: 403));

      expect(exception, isA<ForbiddenException>());
    });

    test('maps 404 to NotFoundException', () {
      final dio = DioException(
        requestOptions: RequestOptions(path: '/users/123'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/123'),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      );

      final exception = mapDioException(dio);

      expect(exception, isA<NotFoundException>());
      expect((exception as NotFoundException).resource, '/users/123');
    });

    test('maps 429 to RateLimitException', () {
      final exception = mapDioException(createDioException(statusCode: 429));

      expect(exception, isA<RateLimitException>());
    });

    test('maps 500 to ServerException', () {
      final exception = mapDioException(createDioException(statusCode: 500));

      expect(exception, isA<ServerException>());
      expect((exception as ServerException).statusCode, 500);
    });

    test('maps 503 to ServerException', () {
      final exception = mapDioException(createDioException(statusCode: 503));

      expect(exception, isA<ServerException>());
      expect((exception as ServerException).statusCode, 503);
    });

    test('maps unhandled status code to UnhandledHttpException', () {
      final exception = mapDioException(
        createDioException(statusCode: 418, message: 'I am a teapot'),
      );

      expect(exception, isA<UnhandledHttpException>());
      expect((exception as UnhandledHttpException).statusCode, 418);
    });

    group('validation error parsing', () {
      test('parses string error data as detail', () {
        final exception = mapDioException(
          createDioException(statusCode: 400, data: 'Bad request'),
        );

        expect(exception, isA<ValidationException>());
        expect((exception as ValidationException).errors, {
          'detail': ['Bad request'],
        });
      });

      test('parses list values in map', () {
        final exception = mapDioException(
          createDioException(
            statusCode: 400,
            data: {
              'email': ['Error 1', 'Error 2'],
            },
          ),
        );

        expect(exception, isA<ValidationException>());
        expect((exception as ValidationException).errors['email'], [
          'Error 1',
          'Error 2',
        ]);
      });

      test('parses string value as single-item list', () {
        final exception = mapDioException(
          createDioException(statusCode: 400, data: {'email': 'Invalid email'}),
        );

        expect(exception, isA<ValidationException>());
        expect((exception as ValidationException).errors['email'], [
          'Invalid email',
        ]);
      });

      test('handles null data gracefully', () {
        final exception = mapDioException(
          createDioException(statusCode: 400, data: null),
        );

        expect(exception, isA<ValidationException>());
        expect((exception as ValidationException).errors, isEmpty);
      });

      test('handles non-map data as detail', () {
        final exception = mapDioException(
          createDioException(statusCode: 400, data: 12345),
        );

        expect(exception, isA<ValidationException>());
        expect((exception as ValidationException).errors, {
          'detail': ['12345'],
        });
      });
    });
  });
}
