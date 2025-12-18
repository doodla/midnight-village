import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User model representing an authenticated user.
@freezed
class User with _$User {
  const factory User({
    required int id,
    @JsonKey(name: 'display_name') required String displayName,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
