import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

import '../../helpers/sheet/sheet_data.dart';

// A player's sigil (their token: the sprig, the spindle) is ONE function of
// the player within a game: the server hands it out once, when they join the
// table (`LobbyMember.token`), copies it to the game's seat at the deal, and
// every screen draws exactly that. Cleo is a thorn at the table and a spindle
// on the night board of the pictures only because those pictures come from two
// different recorded games (`detail_auto_deck_5` and `me_choose_prompt_seer`):
// the table and the board of ONE game agree, and this holds the app to it.
void main() {
  test('the night board draws each seat with the token the server sent', () {
    for (final name in [
      'me_choose_prompt_seer',
      'me_choose_prompt_drunk',
      'me_look_stage',
      'me_talk_ten',
    ]) {
      final me = recordedMe(name);
      final sent = {
        for (final p in (me['players'] as List).cast<Map<String, dynamic>>())
          p['player_id'] as int: TokenId.fromServer(p['token'] as String),
      };
      final seats = NightSeat.seatsOf(me);
      expect(seats, isNotEmpty, reason: name);
      for (final seat in seats) {
        expect(seat.token, isNotNull, reason: '$name ${seat.name}');
        expect(seat.token, sent[seat.id], reason: '$name ${seat.name}');
      }
    }
  });

  test('one player has one sigil in every recorded body of a game', () {
    // Within one game, every body that names a player names their token alike.
    final byGame = <String, Map<int, String>>{};
    final clashes = <String>[];
    void walk(Object? node, String game, String file) {
      if (node is Map) {
        final id = node['player_id'] ?? node['user_id'];
        final token = node['token'];
        if (id is int && token is String) {
          final seen = byGame.putIfAbsent(game, () => {});
          final before = seen[id];
          if (before != null && before != token) {
            clashes.add('$file: game $game player $id is $before and $token');
          }
          seen[id] = token;
        }
        for (final v in node.values) {
          walk(v, game, file);
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v, game, file);
        }
      }
    }

    final samples = Directory('../contract_samples/http')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final file in samples) {
      final Object? body;
      try {
        body = jsonDecode(file.readAsStringSync());
      } on FormatException {
        continue;
      }
      if (body is Map && body['game_id'] != null) {
        walk(body, '${body['game_id']}', file.path.split('/').last);
      }
    }
    expect(clashes, isEmpty);
  });

  test('no code picks a sigil for a player: it is read from the server', () {
    // `TokenId.fromServer` is the only way a token comes into the app; nothing
    // chooses one from a name, an index or a hash.
    final chosen = RegExp(r'TokenId\.(values|people)\b|TokenId\.\w+\s*[,)]');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('skin/art_set.dart') &&
            !f.path.contains('/features/debug/'))
          for (final (n, line) in f.readAsStringSync().split('\n').indexed)
            if (!line.trimLeft().startsWith('//') && chosen.hasMatch(line))
              '${f.path}:${n + 1}: ${line.trim()}',
    ];
    expect(offenders, isEmpty);
  });
}
