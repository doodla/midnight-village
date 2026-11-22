import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/feel/haptics.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/paper_seal.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/shell_setup.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;
import '../../../helpers/truncated_text.dart';

// 09 choosing and locking (feel.md, "Vote (09)"): a finger on a row presses it
// the frame it lands, a pick lifts it, a lock stamps a seal on it and turns its
// paper dried-blood red while the others dim, a tick and a light knock go with
// the pick and the lock (day only), reduce motion cuts every move, and a name
// is whole at ten players on the narrowest phone.

/// The vote as a phone holds it: a tap changes what it shows at once.
class _Host extends StatefulWidget {
  const _Host({required this.me, this.onPick, this.onLock});

  final GameMe me;
  final ValueChanged<int>? onPick;
  final ValueChanged<int>? onLock;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late GameMe _me = widget.me;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: learnedOverrides(Cue.values.toSet()),
    child: VoteView(
      me: _me,
      secondsLeft: 72,
      remaining: null,
      onPick: (id) {
        widget.onPick?.call(id);
        setState(() => _me = _me.withVote(MyVote.local(id, locked: false)));
      },
      onLock: (id) {
        widget.onLock?.call(id);
        setState(() => _me = _me.withVote(MyVote.local(id, locked: true)));
      },
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> me, {
  Size phone = const Size(360, 740),
  bool reduce = false,
  ValueChanged<int>? onPick,
  ValueChanged<int>? onLock,
}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    MediaQuery(
      data: MediaQueryData(size: phone, disableAnimations: reduce),
      child: SizedBox.fromSize(
        size: phone,
        child: _Host(me: GameMe.fromJson(me), onPick: onPick, onLock: onLock),
      ),
    ),
    ground: GroundKind.day,
  );
  await tester.pump();
}

Map<String, dynamic> _tableOf(int more, Map<String, String> rename) {
  final me = sheet.tableOf(
    sheet.recordedMe('me_voting_unpicked'),
    add: more,
    rename: rename,
  );
  final players = (me['players'] as List).cast<Map<String, dynamic>>();
  // The seats added are seats this phone may vote for too.
  for (final p in players.skip(5)) {
    (me['vote_targets'] as List).add(p['player_id']);
  }
  return me;
}

Finder _row(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(PlayerRow));

PlayerRow _rowOf(WidgetTester tester, String name) =>
    tester.widget<PlayerRow>(_row(name));

/// Where the row's paper is drawn (its dip and lift move it).
double _paperTop(WidgetTester tester, String name) => tester
    .getTopLeft(
      find
          .descendant(
            of: find.descendant(
              of: _row(name),
              matching: find.byType(AnimatedContainer),
            ),
            matching: find.byType(DecoratedBox),
          )
          .first,
    )
    .dy;

BoxDecoration _paperOf(WidgetTester tester, String name) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: _row(name),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  final unpicked = sheet.recordedMe('me_voting_unpicked');
  final cleo = sheet.cleo.name;
  final ben = sheet.fiveSeats[1].name;

  group('choosing', () {
    testWidgets('a finger presses the row the frame it lands, and it comes '
        'back when the finger lifts', (tester) async {
      await _pump(tester, unpicked);
      final rest = _paperTop(tester, ben);
      final finger = await tester.startGesture(tester.getCenter(_row(ben)));
      await tester.pump();
      await tester.pump(Motion.press);
      expect(_paperTop(tester, ben), rest + PlayerRow.dip);
      // Nothing else moves.
      expect(_paperTop(tester, cleo), isNot(rest + PlayerRow.dip));
      await finger.up();
      await tester.pump();
      await tester.pump(Motion.quick);
      // It is the pick now: lifted, not at rest.
      expect(_paperTop(tester, ben), rest - Space.xs);
    });

    testWidgets('sliding off a row cancels the press, with no pick', (
      tester,
    ) async {
      final picks = <int>[];
      await _pump(tester, unpicked, onPick: picks.add);
      final rest = _paperTop(tester, ben);
      final finger = await tester.startGesture(tester.getCenter(_row(ben)));
      await tester.pump(Motion.press);
      await finger.moveTo(tester.getCenter(find.byType(PrimaryButton).last));
      await tester.pump();
      await tester.pump(Motion.quick);
      expect(_paperTop(tester, ben), rest, reason: 'off the row: not pressed');
      await finger.up();
      await tester.pump(Motion.quick);
      expect(_paperTop(tester, ben), rest);
      expect(picks, isEmpty);
    });

    testWidgets('a tap picks: the row lifts and takes the outline, and a tap '
        'on another moves the pick', (tester) async {
      final picks = <int>[];
      await _pump(tester, unpicked, onPick: picks.add);
      await tester.tap(_row(cleo));
      await tester.pump(Motion.quick);
      expect(_rowOf(tester, cleo).picked, isTrue);
      expect(_rowOf(tester, ben).picked, isFalse);
      expect(find.text(VoteCopy.lockIn.fill({'name': cleo})), findsOneWidget);
      await tester.tap(_row(ben));
      await tester.pump(Motion.quick);
      expect(_rowOf(tester, ben).picked, isTrue);
      expect(_rowOf(tester, cleo).picked, isFalse);
      expect(picks, hasLength(2));
    });

    testWidgets('reduce motion: the press is a tint, not a move; the pick '
        'is at its place at once', (tester) async {
      await _pump(tester, unpicked, reduce: true);
      final rest = _paperTop(tester, ben);
      final plain = _paperOf(tester, ben).color;
      final finger = await tester.startGesture(tester.getCenter(_row(ben)));
      await tester.pump();
      expect(_paperTop(tester, ben), rest);
      expect(_paperOf(tester, ben).color, isNot(plain));
      await finger.up();
      await tester.pump();
      expect(_paperTop(tester, ben), rest - Space.xs, reason: 'one frame');
    });
  });

  group('locking', () {
    Future<void> lock(WidgetTester tester) async {
      await tester.tap(_row(cleo));
      await tester.pump(Motion.quick);
      await tester.tap(find.byType(PrimaryButton).last);
    }

    testWidgets('a lock stamps a seal on the pick, turns its paper red and '
        'dims the rest; the button says Locked', (tester) async {
      await _pump(tester, unpicked);
      expect(find.byType(PaperSeal), findsNothing);
      await lock(tester);
      await tester.pump(Motion.quick);
      expect(find.byType(PaperSeal), findsOneWidget);
      expect(
        find.descendant(of: _row(cleo), matching: find.byType(PaperSeal)),
        findsOneWidget,
      );
      expect(_rowOf(tester, cleo).sealed, isTrue);
      expect(_rowOf(tester, cleo).picked, isTrue, reason: 'stays lifted');
      expect(_paperOf(tester, cleo).color, const Color(0xFF80241E));
      expect(_rowOf(tester, ben).dimmed, isTrue);
      expect(_rowOf(tester, ben).sealed, isFalse);
      expect(find.text(VoteCopy.locked), findsOneWidget);
      await tester.pump(Motion.settle);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the seal lands: it comes down large and settles, over '
        '`quick`', (tester) async {
      await _pump(tester, unpicked);
      await lock(tester);
      await tester.pump(const Duration(milliseconds: 20));
      double scale() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(PaperSeal),
                  matching: find.byType(Transform),
                )
                .last,
          )
          .transform
          .getMaxScaleOnAxis();
      final early = scale();
      expect(early, greaterThan(1.2));
      await tester.pump(Motion.quick);
      expect(scale(), closeTo(1, 0.001));
    });

    testWidgets('the words turn to bone with the paper: never bone on bone '
        'mid-way', (tester) async {
      await _pump(tester, unpicked);
      await lock(tester);
      await tester.pump(const Duration(milliseconds: 40));
      final style = tester.widget<Text>(find.text(cleo)).style!;
      final paper = _paperOf(tester, cleo).color!;
      // Mid-way both are between their ends; the words are never the paper's
      // own colour.
      expect(style.color, isNot(paper));
      await tester.pump(Motion.quick);
      expect(tester.widget<Text>(find.text(cleo)).style!.color, isNot(paper));
    });

    testWidgets('reduce motion: the lock is the end state in one frame', (
      tester,
    ) async {
      await _pump(tester, unpicked, reduce: true);
      await lock(tester);
      await tester.pump();
      expect(_paperOf(tester, cleo).color, const Color(0xFF80241E));
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: _row(ben),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .duration,
        Duration.zero,
      );
      final seal = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(PaperSeal),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(seal.opacity, 1);
    });

    testWidgets('a screen that opens already locked has the seal in place, '
        'no stamp', (tester) async {
      await _pump(tester, sheet.recordedMe('me_voting_locked'));
      expect(find.byType(PaperSeal), findsOneWidget);
      expect(tester.widget<PaperSeal>(find.byType(PaperSeal)).lands, isFalse);
      expect(
        tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byType(PaperSeal),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
    });

    testWidgets('a tap on a dimmed row does nothing', (tester) async {
      final picks = <int>[];
      await _pump(tester, unpicked, onPick: picks.add);
      await lock(tester);
      await tester.pump(Motion.settle);
      picks.clear();
      final rest = _paperTop(tester, ben);
      final finger = await tester.startGesture(tester.getCenter(_row(ben)));
      await tester.pump(Motion.press);
      expect(_paperTop(tester, ben), rest, reason: 'no press either');
      await finger.up();
      await tester.pump(Motion.quick);
      expect(picks, isEmpty);
      expect(_rowOf(tester, ben).picked, isFalse);
    });
  });

  group('names', () {
    const long = {
      'Seat 32': 'Rosalind Fairweather-Okonkwo',
      'Seat 33': 'Maximiliano Bartholomew',
      'Seat 34': 'Esmeralda',
      'Seat 35': 'Wolfgang Penelope',
      'Seat 36': 'Christopher Jo',
    };

    for (final locked in [false, true]) {
      testWidgets('ten players at 360 wide: every name whole, nothing '
          'overflows${locked ? ', locked' : ''}', (tester) async {
        await _pump(tester, _tableOf(5, long));
        await tester.tap(_row('Rosalind Fairweather-Okonkwo'));
        await tester.pump(Motion.quick);
        if (locked) {
          await tester.tap(find.byType(PrimaryButton).last);
          await tester.pump(Motion.settle);
        }
        for (final name in long.values) {
          expect(_row(name), findsOneWidget, reason: name);
        }
        expect(truncatedText(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('five at 360 wide: the rows use the room, no empty foot', (
      tester,
    ) async {
      await _pump(tester, unpicked);
      final last = tester.getRect(_row(sheet.fiveSeats.last.name)).bottom;
      final pips = tester.getTopLeft(find.textContaining('locked')).dy;
      // The last row ends within one gap of the count under the rows.
      expect(pips - last, lessThan(Space.xl + Space.lg));
      expect(tester.takeException(), isNull);
    });
  });

  group('touch feedback', () {
    late List<String> buzzes;

    setUp(() => buzzes = []);

    void listen(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            buzzes.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('the vote: a tick for each pick, a light knock for the lock '
        'on the tap', (tester) async {
      listen(tester);
      final s = await ShellSetup.pump(
        tester,
        sheet.recordedMe('me_voting_unpicked'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      expect(buzzes, isEmpty);
      s.answerPost('/vote/', 'game/vote_repicked');
      await tester.tap(find.text(cleo));
      await tester.pump();
      expect(buzzes, ['HapticFeedbackType.selectionClick']);
      s.answerPost('/vote/', 'game/vote_locked');
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(buzzes.last, 'HapticFeedbackType.lightImpact');
      expect(buzzes, hasLength(2), reason: 'on the tap, once');
      await s.settle(tester);
      expect(buzzes, hasLength(2), reason: 'not again on the answer');
      await s.close(tester);
    });

    testWidgets('nothing buzzes on the night\'s ground, whoever asks', (
      tester,
    ) async {
      listen(tester);
      late BuildContext context;
      await pumpSkinned(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      Haptics.tick(context);
      Haptics.light(context);
      Haptics.thud(context);
      await tester.pump();
      expect(buzzes, isEmpty);
    });

    testWidgets('on the day the three names are the three light ones', (
      tester,
    ) async {
      listen(tester);
      late BuildContext context;
      await pumpSkinned(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
        ground: GroundKind.day,
      );
      Haptics.tick(context);
      Haptics.light(context);
      Haptics.thud(context);
      await tester.pump();
      expect(buzzes, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
    });
  });
}
