import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/feel/haptics.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/paper_seal.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/painted_text.dart' show contrast;
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
  const _Host({
    required this.me,
    this.onPick,
    this.onLock,
    this.accepts = VoteRows.defaultAccepts,
  });

  final GameMe me;
  final ValueChanged<int>? onPick;
  final ValueChanged<int>? onLock;
  final bool Function() accepts;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late GameMe _me = widget.me;
  var _seconds = 72;

  /// The screen's timer ticking: a rebuild of everything under it.
  void tick() => setState(() => _seconds--);

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: learnedOverrides(Cue.values.toSet()),
    child: VoteView(
      me: _me,
      secondsLeft: _seconds,
      remaining: null,
      accepts: widget.accepts,
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
  double textScale = 1,
  ValueChanged<int>? onPick,
  ValueChanged<int>? onLock,
  bool Function() accepts = VoteRows.defaultAccepts,
}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: phone,
        disableAnimations: reduce,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox.fromSize(
        size: phone,
        child: _Host(
          me: GameMe.fromJson(me),
          onPick: onPick,
          onLock: onLock,
          accepts: accepts,
        ),
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

/// The colour the row's paper is painted in on this frame (the decoration
/// the frame draws, not the one the row is going to).
Color _paintedPaper(WidgetTester tester, String name) =>
    (tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.descendant(
                      of: _row(name),
                      matching: find.byType(AnimatedContainer),
                    ),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .firstWhere((d) => d.position == DecorationPosition.background)
                .decoration
            as BoxDecoration)
        .color!;

Rect _bounds(Iterable<Offset> points) {
  final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
  return Rect.fromLTRB(
    xs.reduce(math.min),
    ys.reduce(math.min),
    xs.reduce(math.max),
    ys.reduce(math.max),
  );
}

/// The seal's four corners as drawn this frame (its tilt and scale in),
/// as the box that holds them.
Rect _sealBox(WidgetTester tester) {
  final seal = find.descendant(
    of: find.byType(PaperSeal),
    matching: find.byType(CustomPaint),
  );
  return _bounds([
    tester.getTopLeft(seal),
    tester.getTopRight(seal),
    tester.getBottomLeft(seal),
    tester.getBottomRight(seal),
  ]);
}

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

    testWidgets('a lock stamps a seal on the pick and dims '
        'the rest; the button says Locked', (tester) async {
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
      // The lock turns the pick's paper dried-blood red.
      expect(_paperOf(tester, cleo).color, const Color(0xFF80241E));
      expect(_rowOf(tester, ben).dimmed, isTrue);
      expect(_rowOf(tester, ben).sealed, isFalse);
      expect(find.text(VoteCopy.locked), findsOneWidget);
      await tester.pump(Motion.settle);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the words read on the paper on every frame '
        'of the lock (4.5:1 at least)', (tester) async {
      await _pump(tester, unpicked);
      await tester.tap(_row(cleo));
      await tester.pump(Motion.quick);
      final before = contrast(
        tester.widget<Text>(find.text(cleo)).style!.color!,
        _paintedPaper(tester, cleo),
      );
      expect(before, greaterThanOrEqualTo(4.5), reason: 'before the lock');
      await tester.tap(find.byType(PrimaryButton).last);
      var frames = 0;
      // The tap's own frame, then a frame every 17 ms until it settles.
      for (var t = 0; t <= Motion.settle.inMilliseconds; t += 17) {
        await tester.pump(
          t == 0 ? Duration.zero : const Duration(milliseconds: 17),
        );
        final ink = tester.widget<Text>(find.text(cleo)).style!.color!;
        final paper = _paintedPaper(tester, cleo);
        expect(
          contrast(ink, paper),
          greaterThanOrEqualTo(4.5),
          reason: 'frame $frames: $ink on $paper',
        );
        frames++;
      }
      expect(frames, greaterThan(10));
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
      expect(early, lessThanOrEqualTo(PaperSeal.landFrom));
      await tester.pump(Motion.quick);
      expect(scale(), closeTo(1, 0.001));
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

  group('the seal', () {
    for (final size in [
      PlayerRowSize.compact,
      PlayerRowSize.large,
      PlayerRowSize.grand,
    ]) {
      for (final name in [sheet.cleo.name, 'Rosalind Fairweather-Okonkwo']) {
        testWidgets('${size.name}, "$name": stays inside the token at rest '
            'and never touches the name while it lands', (tester) async {
          tester.view.physicalSize = const Size(360, 400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          late StateSetter flip;
          var sealed = false;
          await pumpSkinned(
            tester,
            StatefulBuilder(
              builder: (context, set) {
                flip = set;
                return Padding(
                  padding: const EdgeInsets.all(Space.gutter),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: PlayerRow(
                      token: sheet.cleo.token,
                      name: name,
                      size: size,
                      picked: true,
                      sealed: sealed,
                    ),
                  ),
                );
              },
            ),
            ground: GroundKind.day,
          );
          await tester.pump();
          flip(() => sealed = true);
          Rect nameBox() => tester.getRect(find.text(name));
          Rect token() => tester.getRect(find.byType(PlayerToken));
          Rect paper() => tester.getRect(
            find
                .descendant(
                  of: find.descendant(
                    of: find.byType(PlayerRow),
                    matching: find.byType(AnimatedContainer),
                  ),
                  matching: find.byType(DecoratedBox),
                )
                .at(1),
          );
          var frames = 0;
          for (var t = 0; t <= Motion.settle.inMilliseconds; t += 17) {
            await tester.pump(
              t == 0 ? Duration.zero : const Duration(milliseconds: 17),
            );
            final seal = _sealBox(tester);
            expect(
              seal.right,
              lessThan(nameBox().left),
              reason: 'frame $frames: $seal against the name ${nameBox()}',
            );
            expect(seal.overlaps(nameBox()), isFalse, reason: 'frame $frames');
            // Not below the paper (the lift lowers nothing, it raises).
            expect(
              seal.bottom,
              lessThanOrEqualTo(paper().bottom),
              reason: 'frame $frames: $seal below the paper ${paper()}',
            );
            frames++;
          }
          expect(frames, greaterThan(10));
          // At rest: the disc, tilt and shadow all inside the token.
          final seal = _sealBox(tester);
          final at = token();
          expect(seal.left, greaterThanOrEqualTo(at.left));
          expect(seal.top, greaterThanOrEqualTo(at.top));
          expect(seal.right, lessThanOrEqualTo(at.right + 0.5));
          expect(
            seal.bottom + PaperSeal.drop,
            lessThanOrEqualTo(at.bottom + 0.5),
          );
        });
      }
    }
  });

  group('a lock that is not taken', () {
    Future<ShellSetup> picked(WidgetTester tester) async {
      final s = await ShellSetup.pump(
        tester,
        sheet.recordedMe('me_voting_unpicked'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      s.answerPost('/vote/', 'game/vote_repicked');
      await tester.tap(find.text(cleo));
      await tester.pump(Motion.quick);
      return s;
    }

    void expectChoosable(WidgetTester tester) {
      expect(find.byType(PaperSeal), findsNothing, reason: 'no seal');
      for (final seat in sheet.fiveSeats.skip(1)) {
        final row = _rowOf(tester, seat.name);
        expect(row.sealed, isFalse, reason: '${seat.name} not sealed');
        expect(row.dimmed, isFalse, reason: '${seat.name} not dimmed');
        expect(row.onTap, isNotNull, reason: '${seat.name} can be tapped');
        expect(_paintedPaper(tester, seat.name), const Color(0xFFE9E2D0));
      }
      expect(find.text(VoteCopy.locked), findsNothing);
    }

    testWidgets('refused by the server: the rows are choosable again, no '
        'seal, no fill', (tester) async {
      final s = await picked(tester);
      s.answerPost('/vote/', 'game/vote_self', status: 400);
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expectChoosable(tester);
      await s.close(tester);
    });

    testWidgets('no answer at all: the lock is kept as tapped, with "Not '
        'sent." and its own "Try again" (the outbox\'s rule), and the seal '
        'goes when the server then refuses it', (tester) async {
      final s = await picked(tester);
      s.failPost('/vote/');
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      s.answerPost('/vote/', 'game/vote_self', status: 400);
      await tester.tap(find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expectChoosable(tester);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
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

  group('the rows share the room', () {
    for (final players in [2, 3, 4, 6, 10]) {
      testWidgets('$players at 360 wide: no row past the cap, none past '
          '30% of its size, the rest of the room above and below', (
        tester,
      ) async {
        final more = players - 5;
        final me = more >= 0
            ? _tableOf(more, const {})
            : sheet.recordedMe('me_voting_unpicked');
        if (more < 0) {
          // A smaller table: fewer seats this phone may vote for.
          final targets = (me['vote_targets'] as List).cast<int>();
          me['vote_targets'] = targets.take(players).toList();
        }
        await _pump(tester, me);
        final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
        expect(rows, isNotEmpty);
        final heights = [
          for (final row in rows)
            tester.getSize(find.byWidget(row)).height - Space.xs,
        ];
        for (final (i, row) in rows.indexed) {
          expect(heights[i], lessThanOrEqualTo(VoteRows.maxRowHeight + 0.5));
          expect(
            row.stretch,
            lessThanOrEqualTo(row.size.height * VoteRows.maxStretch + 0.01),
          );
        }
      });
    }

    testWidgets('the timer ticking does not measure the names again', (
      tester,
    ) async {
      await _pump(tester, unpicked);
      final after = VoteRows.measured;
      expect(after, greaterThan(0));
      final host = tester.state<_HostState>(find.byType(_Host));
      for (var i = 0; i < 5; i++) {
        host.tick();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(VoteRows.measured, after);
      // A change of the text size does measure again.
      await _pump(tester, unpicked, textScale: 1.5);
      expect(VoteRows.measured, greaterThan(after));
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

    testWidgets('a tap the phone declines makes no tick and no knock', (
      tester,
    ) async {
      listen(tester);
      final picks = <int>[];
      final locks = <int>[];
      await _pump(
        tester,
        sheet.recordedMe('me_voting_unpicked'),
        onPick: picks.add,
        onLock: locks.add,
        accepts: () => false,
      );
      await tester.tap(find.text(cleo));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(picks, hasLength(1), reason: 'the tap still goes to the phone');
      expect(locks, hasLength(1));
      expect(buzzes, isEmpty);
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
