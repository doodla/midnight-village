import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/auth/domain/user.dart';

void main() {
  group('User', () {
    group('constructor validation', () {
      test('creates user with valid id and displayName', () {
        final user = User(id: 1, displayName: 'TestUser');

        expect(user.id, 1);
        expect(user.displayName, 'TestUser');
      });

      test('creates user with large id', () {
        final user = User(id: 999999999, displayName: 'TestUser');

        expect(user.id, 999999999);
      });

      test('throws ArgumentError when id is zero', () {
        expect(
          () => User(id: 0, displayName: 'TestUser'),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'id')
                .having((e) => e.message, 'message', 'must be positive'),
          ),
        );
      });

      test('throws ArgumentError when id is negative', () {
        expect(
          () => User(id: -1, displayName: 'TestUser'),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'id')
                .having((e) => e.message, 'message', 'must be positive'),
          ),
        );
      });

      test('throws ArgumentError when displayName is empty', () {
        expect(
          () => User(id: 1, displayName: ''),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'displayName')
                .having((e) => e.message, 'message', 'must not be empty'),
          ),
        );
      });

      test('throws ArgumentError when displayName is whitespace only', () {
        expect(
          () => User(id: 1, displayName: '   '),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', 'displayName')
                .having((e) => e.message, 'message', 'must not be empty'),
          ),
        );
      });

      test('throws ArgumentError when displayName is tabs and newlines only',
          () {
        expect(
          () => User(id: 1, displayName: '\t\n  '),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fromJson', () {
      test('parses valid JSON', () {
        final json = {'id': 42, 'display_name': 'JsonUser'};

        final user = User.fromJson(json);

        expect(user.id, 42);
        expect(user.displayName, 'JsonUser');
      });

      test('throws ArgumentError for invalid id in JSON', () {
        final json = {'id': 0, 'display_name': 'JsonUser'};

        expect(
          () => User.fromJson(json),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for empty displayName in JSON', () {
        final json = {'id': 1, 'display_name': ''};

        expect(
          () => User.fromJson(json),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('toJson', () {
      test('serializes to JSON with snake_case key', () {
        final user = User(id: 123, displayName: 'TestUser');

        final json = user.toJson();

        expect(json['id'], 123);
        expect(json['display_name'], 'TestUser');
      });
    });
  });
}
