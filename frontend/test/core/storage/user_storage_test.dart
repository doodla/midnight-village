import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late UserStorage userStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    userStorage = UserStorage(storage: mockStorage);
  });

  group('UserStorage', () {
    group('getUser', () {
      test('returns null when no user data is stored', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => null);
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => null);

        final user = await userStorage.getUser();

        expect(user, isNull);
      });

      test('returns null when only displayName is stored', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => 'TestUser');
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => null);

        final user = await userStorage.getUser();

        expect(user, isNull);
      });

      test('returns null when only userId is stored', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => null);
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => '123');

        final user = await userStorage.getUser();

        expect(user, isNull);
      });

      test('returns User when both values are stored and valid', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => 'TestUser');
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => '123');

        final user = await userStorage.getUser();

        expect(user, isNotNull);
        expect(user!.id, 123);
        expect(user.displayName, 'TestUser');
      });

      test(
        'clears and returns null when userId is not a valid integer',
        () async {
          when(
            () => mockStorage.read(key: 'display_name'),
          ).thenAnswer((_) async => 'TestUser');
          when(
            () => mockStorage.read(key: 'user_id'),
          ).thenAnswer((_) async => 'not-a-number');
          when(
            () => mockStorage.delete(key: 'user_id'),
          ).thenAnswer((_) async {});
          when(
            () => mockStorage.delete(key: 'display_name'),
          ).thenAnswer((_) async {});

          final user = await userStorage.getUser();

          expect(user, isNull);
          verify(() => mockStorage.delete(key: 'user_id')).called(1);
          verify(() => mockStorage.delete(key: 'display_name')).called(1);
        },
      );

      test('clears and returns null when userId is zero', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => 'TestUser');
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => '0');
        when(() => mockStorage.delete(key: 'user_id')).thenAnswer((_) async {});
        when(
          () => mockStorage.delete(key: 'display_name'),
        ).thenAnswer((_) async {});

        final user = await userStorage.getUser();

        expect(user, isNull);
        verify(() => mockStorage.delete(key: 'user_id')).called(1);
      });

      test('clears and returns null when userId is negative', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => 'TestUser');
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => '-5');
        when(() => mockStorage.delete(key: 'user_id')).thenAnswer((_) async {});
        when(
          () => mockStorage.delete(key: 'display_name'),
        ).thenAnswer((_) async {});

        final user = await userStorage.getUser();

        expect(user, isNull);
        verify(() => mockStorage.delete(key: 'user_id')).called(1);
      });

      test('clears and returns null when displayName is empty', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => '   ');
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => '123');
        when(() => mockStorage.delete(key: 'user_id')).thenAnswer((_) async {});
        when(
          () => mockStorage.delete(key: 'display_name'),
        ).thenAnswer((_) async {});

        final user = await userStorage.getUser();

        expect(user, isNull);
        verify(() => mockStorage.delete(key: 'user_id')).called(1);
      });
    });

    group('hasUser', () {
      test('returns true when valid user data exists', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => 'TestUser');
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => '123');

        final hasUser = await userStorage.hasUser;

        expect(hasUser, isTrue);
      });

      test('returns false when no user data exists', () async {
        when(
          () => mockStorage.read(key: 'display_name'),
        ).thenAnswer((_) async => null);
        when(
          () => mockStorage.read(key: 'user_id'),
        ).thenAnswer((_) async => null);

        final hasUser = await userStorage.hasUser;

        expect(hasUser, isFalse);
      });
    });

    group('saveUser', () {
      test('saves valid user data', () async {
        when(
          () => mockStorage.write(key: 'user_id', value: '123'),
        ).thenAnswer((_) async {});
        when(
          () => mockStorage.write(key: 'display_name', value: 'TestUser'),
        ).thenAnswer((_) async {});

        await userStorage.saveUser(id: 123, displayName: 'TestUser');

        verify(() => mockStorage.write(key: 'user_id', value: '123')).called(1);
        verify(
          () => mockStorage.write(key: 'display_name', value: 'TestUser'),
        ).called(1);
      });

      test('throws ArgumentError when id is zero', () async {
        expect(
          () => userStorage.saveUser(id: 0, displayName: 'TestUser'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when id is negative', () async {
        expect(
          () => userStorage.saveUser(id: -1, displayName: 'TestUser'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when displayName is empty', () async {
        expect(
          () => userStorage.saveUser(id: 123, displayName: ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'throws ArgumentError when displayName is whitespace only',
        () async {
          expect(
            () => userStorage.saveUser(id: 123, displayName: '   '),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('rolls back userId write when displayName write fails', () async {
        when(
          () => mockStorage.write(key: 'user_id', value: '123'),
        ).thenAnswer((_) async {});
        when(
          () => mockStorage.write(key: 'display_name', value: 'TestUser'),
        ).thenThrow(Exception('Storage full'));
        when(() => mockStorage.delete(key: 'user_id')).thenAnswer((_) async {});

        await expectLater(
          () => userStorage.saveUser(id: 123, displayName: 'TestUser'),
          throwsA(isA<Exception>()),
        );

        verify(() => mockStorage.delete(key: 'user_id')).called(1);
      });

      test('rethrows original error even if rollback fails', () async {
        final originalError = Exception('Storage full');
        when(
          () => mockStorage.write(key: 'user_id', value: '123'),
        ).thenAnswer((_) async {});
        when(
          () => mockStorage.write(key: 'display_name', value: 'TestUser'),
        ).thenThrow(originalError);
        when(
          () => mockStorage.delete(key: 'user_id'),
        ).thenThrow(Exception('Rollback failed'));

        await expectLater(
          () => userStorage.saveUser(id: 123, displayName: 'TestUser'),
          throwsA(same(originalError)),
        );
      });

      test('propagates error when first write (user_id) fails', () async {
        final storageError = Exception('Keychain unavailable');
        when(
          () => mockStorage.write(key: 'user_id', value: '123'),
        ).thenThrow(storageError);

        await expectLater(
          () => userStorage.saveUser(id: 123, displayName: 'TestUser'),
          throwsA(same(storageError)),
        );

        // Verify display_name write was never attempted
        verifyNever(
          () => mockStorage.write(key: 'display_name', value: 'TestUser'),
        );
        // Verify no cleanup was attempted (nothing to clean up)
        verifyNever(() => mockStorage.delete(key: 'user_id'));
        verifyNever(() => mockStorage.delete(key: 'display_name'));
      });
    });

    group('clear', () {
      test('deletes both keys', () async {
        when(() => mockStorage.delete(key: 'user_id')).thenAnswer((_) async {});
        when(
          () => mockStorage.delete(key: 'display_name'),
        ).thenAnswer((_) async {});

        await userStorage.clear();

        verify(() => mockStorage.delete(key: 'user_id')).called(1);
        verify(() => mockStorage.delete(key: 'display_name')).called(1);
      });
    });
  });
}
