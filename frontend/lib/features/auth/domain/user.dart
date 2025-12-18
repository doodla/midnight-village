import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// User model representing an authenticated user.
@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.displayName,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final int id;
  @JsonKey(name: 'display_name')
  final String displayName;

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
