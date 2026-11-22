import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';

import '../../../helpers/outcome_samples.dart';
import '../../../helpers/painted_text.dart';
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/truncated_text.dart';

// 10 The count's arrival (feel.md, "The count (10)"): the votes are struck as
// paper tally marks while the rows land and the beat runs, the cards turn, and
// as they land the rows the vote killed are cut red and the phone knocks, once.
// Nothing is added: the same length as before, a tap finishes it, reduce
// motion starts finished, and every name is whole.

/// The red of a dying row's paper.
const _blood = Color(0xFF80241E);

late List<String> _buzzes;

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> results, {
  required int viewer,
  double width = 360,
  double textScale = 1,
  bool reduced = false,
  GroundKind ground = GroundKind.day,
  VoidCallback? onSeeWhoWon,
}) async {
  _buzzes = [];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        _buzzes.add(call.arguments as String);
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
  final phone = Size(width, 800);
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: phone,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduced,
      ),
      child: SizedBox.fromSize(
        size: phone,
        child: CountView(
          count: TheCount.of(outcomeOf(results)),
          viewerId: viewer,
          onSeeWhoWon: onSeeWhoWon ?? () {},
        ),
      ),
    ),
    ground: ground,
  );
}

List<PlayerRow> _rows(WidgetTester tester) =>
    tester.widgetList<PlayerRow>(find.byType(PlayerRow)).toList();

/// How far each row's votes are struck: per row, the progress of each mark.
List<List<double>> _marks(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final TallyMarks marks) marks.progress,
];

Color _paperOf(WidgetTester tester, String name) {
  final row = find.ancestor(
    of: find.text(name),
    matching: find.byType(AnimatedContainer),
  );
  final box = tester.widget<AnimatedContainer>(row.first).decoration!;
  return (box as BoxDecoration).color!;
}

void main() {
  const dies = 'HapticFeedbackType.mediumImpact';
  const light = 'HapticFeedbackType.lightImpact';

  group('one death', () {
    testWidgets('votes are struck one by one, the cards turn, then the row is '
        'cut red and the phone knocks once', (tester) async {
      final results = recordedResults('results_moved_dead_card');
      await _pump(tester, results, viewer: 55);
      // The first frame: the number is the whole count at once; no mark yet.
      expect(find.text('5'), findsOneWidget);
      expect(_marks(tester).map((m) => m.length), [5, 1]);
      expect(_marks(tester).expand((m) => m).every((p) => p == 0), isTrue);
      // Marks arrive in the beat, in order, with nothing red yet.
      await tester.pump(const Duration(milliseconds: 800));
      final partway = _marks(tester).expand((m) => m).toList();
      expect(partway.where((p) => p > 0), isNotEmpty);
      expect(partway.where((p) => p < 1), isNotEmpty, reason: 'not all yet');
      expect(_rows(tester).any((r) => r.condemned), isFalse);
      expect(_buzzes, isEmpty);
      // The beat is over; the card is turning: still nothing felt.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_marks(tester).expand((m) => m).every((p) => p == 1), isTrue);
      expect(_buzzes, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(_buzzes, [dies]);
      final ben = _rows(tester).firstWhere((r) => r.name == 'Ben');
      expect(ben.condemned, isTrue);
      expect(_paperOf(tester, 'Ben'), _blood);
      expect(_rows(tester).where((r) => r.condemned).map((r) => r.name), [
        'Ben',
      ]);
      await tester.pump(const Duration(seconds: 2));
      expect(_buzzes, hasLength(1), reason: 'once per count');
    });

    testWidgets('the whole count is no longer than before: the cards are up '
        'at the same moment, and a tap finishes it at once', (tester) async {
      await _pump(
        tester,
        recordedResults('results_moved_dead_card'),
        viewer: 55,
      );
      final total =
          Motion.stagger * 1 + Motion.settle + Motion.beat + Motion.reveal;
      await tester.pump(total - const Duration(milliseconds: 20));
      expect(_buzzes, isEmpty);
      await tester.pump(const Duration(milliseconds: 40));
      expect(_buzzes, [dies]);
    });

    testWidgets('a tap anywhere finishes it: red and the knock, once', (
      tester,
    ) async {
      await _pump(
        tester,
        recordedResults('results_moved_dead_card'),
        viewer: 55,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(const Offset(180, 450));
      await tester.pump();
      expect(_rows(tester).firstWhere((r) => r.name == 'Ben').condemned, true);
      expect(_marks(tester).expand((m) => m).every((p) => p == 1), isTrue);
      expect(_buzzes, [dies]);
      await tester.pump(const Duration(seconds: 3));
      expect(_buzzes, hasLength(1));
    });
  });

  testWidgets('a tie of two: both rows are red, two cards, one knock', (
    tester,
  ) async {
    await _pump(tester, recordedResults('results_tie'), viewer: 56);
    await tester.pump(const Duration(seconds: 6));
    expect(_rows(tester).where((r) => r.condemned).map((r) => r.name).toSet(), {
      'Cleo',
      'Dev',
    });
    expect(_paperOf(tester, 'Cleo'), _blood);
    expect(_paperOf(tester, 'Dev'), _blood);
    // Their marks are as many as the votes the server counted.
    expect(_marks(tester).map((m) => m.length), [2, 2, 1, 1]);
    expect(_buzzes, [dies], reason: 'one knock for two cards');
  });

  testWidgets('the Hunter: only the rows the vote killed turn red', (
    tester,
  ) async {
    await _pump(tester, recordedResults('results'), viewer: 55);
    await tester.pump(const Duration(seconds: 6));
    final red = _rows(tester).where((r) => r.condemned).map((r) => r.name);
    expect(red, ['Fin']);
  });

  testWidgets('nobody dies: no red, no cards, a light knock when the marks '
      'are done, and no more time than the rows took', (tester) async {
    await _pump(tester, recordedResults('results_nobody_dies'), viewer: 56);
    expect(_rows(tester), hasLength(6));
    final landing = Motion.stagger * 5 + Motion.settle;
    await tester.pump(landing - const Duration(milliseconds: 20));
    expect(_buzzes, isEmpty);
    await tester.pump(const Duration(milliseconds: 40));
    expect(_buzzes, [light]);
    expect(_rows(tester).any((r) => r.condemned), isFalse);
    expect(_marks(tester).expand((m) => m).every((p) => p == 1), isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(_buzzes, hasLength(1));
  });

  group('reduce motion', () {
    testWidgets('one death: red, every mark, the card up and the knock on '
        'the first frames', (tester) async {
      await _pump(
        tester,
        recordedResults('results_moved_dead_card'),
        viewer: 55,
        reduced: true,
      );
      await tester.pump();
      expect(_rows(tester).firstWhere((r) => r.name == 'Ben').condemned, true);
      expect(_marks(tester).expand((m) => m).every((p) => p == 1), isTrue);
      expect(find.text('Werewolf'), findsOneWidget);
      expect(_buzzes, [dies]);
    });

    testWidgets('nobody: all marks at once, a light knock', (tester) async {
      await _pump(
        tester,
        recordedResults('results_nobody_dies'),
        viewer: 56,
        reduced: true,
      );
      await tester.pump();
      expect(_marks(tester).expand((m) => m).every((p) => p == 1), isTrue);
      expect(_buzzes, [light]);
    });
  });

  testWidgets('the knock comes from the count\'s own day ground', (
    tester,
  ) async {
    await _pump(
      tester,
      recordedResults('results_moved_dead_card'),
      viewer: 55,
      reduced: true,
      ground: GroundKind.night,
    );
    await tester.pump();
    // The screen sets its own day ground: it knocks (the count is a day
    // screen), which a night ground above it does not change.
    expect(_buzzes, [dies]);
  });

  group('ten players, long names', () {
    for (final (width, scale) in [(320.0, 1.0), (360.0, 1.0), (360.0, 1.6)]) {
      testWidgets('every name whole at $width wide, text x$scale, on every '
          'frame', (tester) async {
        final results = widened(
          recordedResults('results_doppelganger'),
          add: 2,
          rename: longEndNames,
        );
        await _pump(
          tester,
          results,
          viewer: 56,
          width: width,
          textScale: scale,
        );
        for (var ms = 0; ms <= 2600; ms += 200) {
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull, reason: '$ms ms');
          expect(truncatedText(tester), isEmpty, reason: '$ms ms');
        }
        for (final name in longEndNames.values) {
          expect(find.textContaining(name), findsWidgets);
        }
      });
    }

    testWidgets('nine votes on one player: the marks fit beside a long name '
        'at 320 wide', (tester) async {
      // Everyone votes for Fin (a Villager with a long name).
      final results = recordedResults('results_doppelganger');
      final players = (results['players'] as List).cast<Map<String, dynamic>>();
      final fin = players.firstWhere((p) => p['display_name'] == 'Fin');
      for (final p in players) {
        if (p != fin) p['vote_target_id'] = fin['player_id'];
        p['is_eliminated'] = p == fin;
        p['elimination_reason'] = p == fin ? 'vote' : null;
      }
      fin['display_name'] = 'Rosalind Fairweather';
      await _pump(tester, results, viewer: 55, width: 320, textScale: 1.3);
      await tester.pump(const Duration(seconds: 6));
      expect(_marks(tester).first, hasLength(7));
      expect(truncatedText(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('the words read on every frame (4.5:1 at least)', () {
    for (final (name, sample, viewer) in [
      ('one death', 'results_moved_dead_card', 55),
      ('a tie', 'results_tie', 56),
      ('nobody', 'results_nobody_dies', 56),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, recordedResults(sample), viewer: viewer);
        // From the first frame, every 100 ms through the landing, the marks,
        // the turn, the red cut and the end.
        await tester.pump(const Duration(milliseconds: 1));
        var frames = 0;
        for (var ms = 0; ms < 3000; ms += 100) {
          await tester.pump(const Duration(milliseconds: 100));
          for (final run in await readPaintedText(tester)) {
            expect(run.passes, isTrue, reason: '$ms ms: $run');
          }
          frames++;
        }
        expect(frames, 30);
      });
    }
  });
}
