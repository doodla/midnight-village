// Example: Unit testing a domain model
//
// Pattern: Pure Dart tests — no Flutter, no pumpWidget.
// Copy this for any model in lib/features/<feature>/domain/.
//
// To adapt for your model:
//   1. Replace the import with your domain model
//   2. Replace the group name and test cases
//   3. Focus on invariants: what can/can't this model represent?

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/auth/domain/user.dart';

void main() {
  group('User', () {
    // Happy path: valid construction
    test('creates with valid id and display name', () {
      final user = User(id: 42, displayName: 'Alice');
      expect(user.id, 42);
      expect(user.displayName, 'Alice');
    });

    // Invariant: id must be positive
    test('throws ArgumentError for id of zero', () {
      expect(() => User(id: 0, displayName: 'Alice'), throwsArgumentError);
    });

    test('throws ArgumentError for negative id', () {
      expect(() => User(id: -1, displayName: 'Alice'), throwsArgumentError);
    });

    // Invariant: displayName must be non-empty after trimming
    test('throws ArgumentError for empty display name', () {
      expect(() => User(id: 1, displayName: ''), throwsArgumentError);
    });

    test('throws ArgumentError for whitespace-only display name', () {
      expect(() => User(id: 1, displayName: '   '), throwsArgumentError);
    });

    // Serialization round-trip
    test('serializes to JSON with snake_case key', () {
      final user = User(id: 7, displayName: 'Bob');
      final json = user.toJson();
      expect(json['id'], 7);
      expect(json['display_name'], 'Bob');
    });

    test('deserializes from JSON with snake_case key', () {
      final user = User.fromJson({'id': 3, 'display_name': 'Carol'});
      expect(user.id, 3);
      expect(user.displayName, 'Carol');
    });
  });
}
