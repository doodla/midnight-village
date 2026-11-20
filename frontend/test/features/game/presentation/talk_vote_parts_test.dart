import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/stage_seconds.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;

// The parts 08 and 09 are drawn with: the share of a stage left, the
// timer band with nothing known, who may be voted for, the vote's rows.

void main() {
  group('StageShare', () {
    // A recorded vote (120 s from `stage_started_at` to `deadline`).
    final vote = GameMe.fromJson(sheet.recordedMe('me_voting_ten'));
    final start = vote.stageStartedAt!;
    final deadline = vote.deadline!;
    final length = deadline.difference(start).inSeconds;

    test('the seconds left over the length the server set', () {
      expect(
        StageShare.left(
          startedAt: start,
          deadline: deadline,
          secondsLeft: length,
        ),
        1,
      );
      expect(
        StageShare.left(
          startedAt: start,
          deadline: deadline,
          secondsLeft: length ~/ 2,
        ),
        0.5,
      );
      expect(
        StageShare.left(startedAt: start, deadline: deadline, secondsLeft: 0),
        0,
      );
    });

    test('nothing for an untimed stage (the server sends no start and no '
        'deadline): no length is assumed', () {
      for (final name in ['me_talk_untimed', 'me_voting_untimed']) {
        final me = GameMe.fromJson(sheet.recordedMe(name));
        expect((me.stageStartedAt, me.deadline), (null, null), reason: name);
        expect(
          StageShare.left(
            startedAt: me.stageStartedAt,
            deadline: me.deadline,
            secondsLeft: null,
          ),
          isNull,
          reason: name,
        );
      }
    });

    test('clamped to 0..1 (a clock a little off at the ends)', () {
      expect(
        StageShare.left(
          startedAt: start,
          deadline: deadline,
          secondsLeft: length + 5,
        ),
        1,
      );
      expect(
        StageShare.left(startedAt: deadline, deadline: start, secondsLeft: 3),
        0,
      );
    });
  });

  group('TimerBand', () {
    testWidgets('no deadline: no number, the title alone, the bar unlit', (
      tester,
    ) async {
      await pumpSkinned(
        tester,
        const TimerBand.bar(
          secondsLeft: null,
          remaining: 0.8,
          title: VoteCopy.headline,
        ),
        ground: GroundKind.day,
      );
      expect(find.text(VoteCopy.headline), findsOneWidget);
      expect(find.byType(FitLine), findsNothing, reason: 'no number');
      final lit = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(lit.widthFactor, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no share: the number, and the bar unlit', (tester) async {
      await pumpSkinned(
        tester,
        const TimerBand.bar(secondsLeft: 72, remaining: null),
        ground: GroundKind.day,
      );
      expect(find.text('1:12'), findsOneWidget);
      expect(
        tester
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        0,
      );
    });

    testWidgets('with a share, that much of the bar is lit', (tester) async {
      await pumpSkinned(
        tester,
        const TimerBand.bar(secondsLeft: 27, remaining: 0.3),
        ground: GroundKind.day,
      );
      expect(
        tester
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        0.3,
      );
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('the title beside the number where they fit, under it '
          'where not (text x$scale, 320 wide)', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(scale),
            ),
            child: Builder(builder: (context) => const SizedBox.shrink()),
          ),
        );
        await pumpSkinned(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const SizedBox(
              width: 320,
              child: TimerBand.bar(
                secondsLeft: 18,
                remaining: null,
                title: VoteCopy.headline,
              ),
            ),
          ),
          ground: GroundKind.day,
        );
        final number = tester.getRect(find.text('18'));
        final title = tester.getRect(find.text(VoteCopy.headline));
        if (scale == 1) {
          expect(title.left, greaterThan(number.right), reason: 'beside');
        } else {
          expect(
            title.top,
            greaterThanOrEqualTo(number.bottom),
            reason: 'under',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('who may be voted for', () {
    test('exactly the vote_targets /me/ names, in seat order', () {
      for (final name in [
        'me_voting_unpicked',
        'me_voting_ten',
        'me_voting_untimed',
      ]) {
        final json = sheet.recordedMe(name);
        final me = GameMe.fromJson(json);
        expect(
          VoteView.votable(me).map((s) => s.id),
          (json['vote_targets'] as List).cast<int>(),
          reason: name,
        );
        expect(
          VoteView.votable(me).map((s) => s.id),
          isNot(contains(me.playerId)),
        );
      }
      expect(
        VoteView.votable(GameMe.fromJson(sheet.recordedMe('me_voting_ten'))),
        hasLength(9),
      );
    });
  });

  group("the vote's rows are sized to the room", () {
    final ten = sheet.tableOf(
      sheet.recordedMe('me_voting_unpicked'),
      add: 5,
      rename: const {
        'Ana': 'Christopher',
        'Ben': 'Maximiliano',
        'Seat 33': 'Rosalind Fairweather',
        'Seat 34': 'Bartholomew',
      },
    );
    final me = GameMe.fromJson(ten);

    Future<void> pump(WidgetTester tester, Size phone, double scale) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSkinned(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: phone,
            textScaler: TextScaler.linear(scale),
          ),
          child: SizedBox.fromSize(
            size: phone,
            child: _Learned(
              child: VoteView(
                me: me,
                secondsLeft: 72,
                remaining: null,
                onPick: (_) {},
                onLock: (_) {},
              ),
            ),
          ),
        ),
        ground: GroundKind.day,
      );
      await tester.pump();
    }

    testWidgets('three: the tall rows', (tester) async {
      final three = GameMe.fromJson(
        sheet.tableOf(
          sheet.recordedMe('me_voting_unpicked'),
          leave: {sheet.dev.name, sheet.esme.name},
        ),
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSkinned(
        tester,
        SizedBox.fromSize(
          size: const Size(320, 568),
          child: _Learned(
            child: VoteView(
              me: three,
              secondsLeft: 72,
              remaining: null,
              onPick: (_) {},
              onLock: (_) {},
            ),
          ),
        ),
        ground: GroundKind.day,
      );
      final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
      expect(rows.every((r) => r.size == PlayerRowSize.large), isTrue);
      expect(find.byType(FadingScroll), findsNothing);
    });

    testWidgets('ten long names on a 320 x 844 phone: every row on screen, '
        'nothing scrolls', (tester) async {
      await pump(tester, const Size(320, 844), 1);
      expect(find.byType(FadingScroll), findsNothing);
      final pips = tester.getTopLeft(find.textContaining('locked')).dy;
      for (final row in find.byType(PlayerRow).evaluate()) {
        expect(
          tester.getRect(find.byWidget(row.widget)).bottom,
          lessThan(pips),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('where nothing fits (320 x 568 at text x2), the rows scroll '
        'with the fade below them', (tester) async {
      await pump(tester, const Size(320, 568), 2);
      expect(find.byType(FadingScroll), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A device that has learned every cue (no nudge).
class _Learned extends StatelessWidget {
  const _Learned({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: learnedOverrides(Cue.values.toSet()),
    child: child,
  );
}
