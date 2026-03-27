import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// User model representing an authenticated user.
///
/// Invariants:
/// - [id] must be positive (> 0)
/// - [displayName] must be non-empty after trimming
///
/// Note: This class intentionally uses a non-const constructor to enforce
/// invariants at runtime. This prevents creation of invalid User instances
/// at the cost of not supporting compile-time const construction.
@JsonSerializable()
class User {
  User({required this.id, required this.displayName}) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be positive');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'must not be empty');
    }
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final int id;
  @JsonKey(name: 'display_name')
  final String displayName;

  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName;

  @override
  int get hashCode => id.hashCode ^ displayName.hashCode;
}
