import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../../test_screens/shell_fixtures.dart';
import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/day_pages.dart';
import '../../helpers/sheet/end_pages.dart';
import '../../helpers/sheet/night_pages.dart';
import '../../helpers/sheet/sheet_data.dart';
import '../../helpers/sheet/table_pages.dart';

// One game, one sigil per player, on every screen (the art director saw Cleo
// with a sprig on the table and a spindle on the night board: two pictures of
// two recorded games, `sigil_test.dart`). Here ONE recorded game (game 7: Ana
// the moth, Ben the hare, Cleo the spindle, Dev the scythe, Esme the bell) is
// drawn by the real table, night board, vote, count and results, and every
// token drawn beside a player's name is the one the server gave that player.
void main() {
  final names = {for (final s in fiveSeats) s.name: s.token};

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: learnedOverrides(ComponentPage.action.learned),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skinTheme(skinsUnderTest.values.first),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: home,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// The tokens drawn beside a name: for each token, the one name in the
  /// smallest block of the screen that holds a name.
  Map<String, TokenId?> drawn(WidgetTester tester) {
    final out = <String, TokenId?>{};
    Set<String> namesUnder(Element root) {
      final found = <String>{};
      void visit(Element e) {
        final w = e.widget;
        final text = w is Text
            ? w.data
            : w is RichText
            ? w.text.toPlainText()
            : null;
        if (text != null && names.containsKey(text)) found.add(text);
        e.visitChildren(visit);
      }

      visit(root);
      return found;
    }

    for (final e in tester.elementList(find.byType(PlayerToken))) {
      final token = (e.widget as PlayerToken).token;
      Set<String>? mine;
      e.visitAncestorElements((a) {
        final found = namesUnder(a);
        if (found.isEmpty) return true;
        mine = found;
        return false;
      });
      if (mine == null || mine!.length != 1) continue;
      final name = mine!.single;
      expect(
        out[name] ?? token,
        token,
        reason: '$name is drawn with two sigils on one screen',
      );
      out[name] = token;
    }
    return out;
  }

  final screens = <String, Widget Function()>{
    'the table (host)': () => const TablePage(lobby: gameSevenLobby),
    'the table (guest)': () =>
        const TablePage(guest: true, lobby: gameSevenLobby),
    'the night board': () => const BoardPage(viewer: Viewer.seer),
    'the vote': () => const VotePage(),
    'the count': () => CountPage(game: EndGame.five),
    'the results': () => ResultsPage(viewer: Viewer.seer, game: EndGame.five),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: every player has the server\'s sigil', (
      tester,
    ) async {
      await show(tester, entry.value());
      final seen = drawn(tester);
      expect(
        seen.length,
        greaterThanOrEqualTo(entry.key == 'the count' ? 1 : 2),
        reason: 'no names beside tokens',
      );
      for (final e in seen.entries) {
        expect(e.value, names[e.key], reason: '${entry.key}: ${e.key}');
      }
    });
  }

  testWidgets('the shell (your card) is of the same game', (tester) async {
    // The card back's own `/me/` is game 7's: the same five tokens.
    final me = recordedMe('me_look_stage');
    final sent = {
      for (final p in (me['players'] as List).cast<Map<String, dynamic>>())
        p['display_name'] as String: TokenId.fromServer(p['token'] as String),
    };
    expect(sent, names);
    await pumpYourCard(tester);
  });
}
