// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voting_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VoteProgress _$VoteProgressFromJson(Map<String, dynamic> json) =>
    _VoteProgress(
      playerVoted:
          (json['playerVoted'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k), e as bool),
          ) ??
          const {},
      currentPlayerVoted: json['currentPlayerVoted'] as bool? ?? false,
    );

Map<String, dynamic> _$VoteProgressToJson(
  _VoteProgress instance,
) => <String, dynamic>{
  'playerVoted': instance.playerVoted.map((k, e) => MapEntry(k.toString(), e)),
  'currentPlayerVoted': instance.currentPlayerVoted,
};

_VoteRevealData _$VoteRevealDataFromJson(Map<String, dynamic> json) =>
    _VoteRevealData(
      votes: Map<String, int?>.from(json['votes'] as Map),
      tally: Map<String, int>.from(json['tally'] as Map),
    );

Map<String, dynamic> _$VoteRevealDataToJson(_VoteRevealData instance) =>
    <String, dynamic>{'votes': instance.votes, 'tally': instance.tally};
