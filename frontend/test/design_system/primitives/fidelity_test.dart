import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/count_badge.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

// The primitives measured against the mocks' markup (docs/design/mocks/
// S*.dc.html), in Shadow paper, whose values are the mocks'.

final _skin = SkinId.fallback.skin;

Future<void> _pump(WidgetTester tester, Widget child, {GroundKind? ground}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return pumpSkinned(
    tester,
    SizedBox(width: 342, child: child),
    ground: ground ?? GroundKind.night,
  );
}

BoxDecoration _decoration(WidgetTester tester, Finder of) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(of: of, matching: find.byType(AnimatedContainer)),
            )
            .decoration!
        as BoxDecoration;

void main() {
  group('buttons: two sizes on the main screens, one in sheets', () {
    for (final (size, height, shadow) in [
      (ButtonSize.large, 50.0, 6.0), // S01, S04, S11
      (ButtonSize.regular, 48.0, 5.0), // S02, S03, S06 to S10
      (ButtonSize.compact, 48.0, 4.0), // S03b
    ]) {
      testWidgets('${size.name}: $height tall, a $shadow,$shadow shadow', (
        tester,
      ) async {
        await _pump(
          tester,
          Center(
            child: PrimaryButton(label: 'Go', onPressed: () {}, size: size),
          ),
        );
        final button = find.byType(PrimaryButton);
        expect(tester.getSize(button).height, height);
        expect(
          _decoration(tester, button).boxShadow!.single.offset,
          Offset(shadow, shadow),
        );
        expect(
          tester.widget<Text>(find.text('Go')).style!.fontSize,
          size.label(_skin.typography).fontSize,
        );
      });
    }

    testWidgets('a secondary button is 48 tall, in a sheet too', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: [
            SecondaryButton(label: 'A', onPressed: () {}),
            SecondaryButton(
              label: 'B',
              onPressed: () {},
              size: ButtonSize.compact,
            ),
          ],
        ),
      );
      final [a, b] = tester.widgetList(find.byType(SecondaryButton)).toList();
      expect(tester.getSize(find.byWidget(a)).height, 48);
      expect(tester.getSize(find.byWidget(b)).height, 48);
    });
  });

  group('player rows', () {
    for (final (size, height, token, gap, end) in [
      (PlayerRowSize.lobby, 38.0, 26.0, 10.0, 10.0), // S02
      (PlayerRowSize.compact, 48.0, 32.0, 12.0, 12.0), // S09 fallback
      (PlayerRowSize.large, 52.0, 38.0, 14.0, 16.0), // S09
      (PlayerRowSize.count, 52.0, 34.0, 12.0, 14.0), // S10
    ]) {
      testWidgets(
        '${size.name}: $height tall, a $token token, $gap to the name, '
        '$end at the end',
        (tester) async {
          await _pump(
            tester,
            PlayerRow(
              token: TokenId.moth,
              name: 'Cleo',
              size: size,
              trailing: const Tally(3),
            ),
            ground: GroundKind.day,
          );
          final row = tester.getRect(find.byType(PlayerRow));
          final tokenRect = tester.getRect(find.byType(PlayerToken));
          expect(row.height, height);
          expect(tokenRect.width, token);
          expect(tester.getRect(find.text('Cleo')).left - tokenRect.right, gap);
          expect(row.right - tester.getRect(find.text('3')).right, end);
        },
      );
    }

    testWidgets('the trailing part keeps its own type (the tally is 20)', (
      tester,
    ) async {
      await _pump(
        tester,
        const PlayerRow(
          token: TokenId.bell,
          name: 'Dev',
          size: PlayerRowSize.count,
          trailing: Tally(3),
        ),
      );
      final style = DefaultTextStyle.of(
        tester.element(find.text('3')),
      ).style.merge(tester.widget<Text>(find.text('3')).style);
      expect(style.fontSize, 20);
    });
  });

  testWidgets('a dropped member\'s token is dimmed to 0.4 in the idle ring', (
    tester,
  ) async {
    await _pump(
      tester,
      const PlayerToken(TokenId.crow, away: true),
      ground: GroundKind.day,
    );
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.4);
    final ring =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(PlayerToken),
                    matching: find.byType(Container),
                  ),
                )
                .foregroundDecoration!
            as BoxDecoration;
    expect((ring.border! as Border).top.color, _skin.day.idle);
  });

  group('face-down cards', () {
    testWidgets('lie with a vertical shadow (0, 4), not a diagonal one', (
      tester,
    ) async {
      await _pump(tester, const Center(child: FaceDownCard()));
      expect(tester.getSize(find.byType(FaceDownCard)), const Size(78, 106));
      final card = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(FaceDownCard),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((c) => c.decoration is BoxDecoration);
      final shadows = (card.decoration! as BoxDecoration).boxShadow!;
      expect(shadows.last.offset, const Offset(0, 4));
      expect(shadows.last.blurRadius, 0, reason: 'the shadow stays hard');
      // The picked card's light is in the list, unlit, so it fades with the
      // pick (face_down_feel_test.dart).
      expect(shadows.length, 2);
      expect(shadows.first.color.a, 0);
      expect(shadows.first.blurRadius, 0, reason: 'nothing soft to paint');
    });

    testWidgets('shrink with their parent: four to a 320 phone', (
      tester,
    ) async {
      // A 320 phone's 272 between the gutters, four cards and three gaps.
      await _pump(
        tester,
        Center(
          child: SizedBox(
            width: 272,
            child: Row(
              spacing: Space.xs,
              children: [
                for (var i = 0; i < 4; i++)
                  const Expanded(child: FaceDownCard(owner: TokenId.key)),
              ],
            ),
          ),
        ),
      );
      final back = tester.getSize(
        find
            .descendant(
              of: find.byType(FaceDownCard).first,
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(back.width, closeTo((272 - 3 * Space.xs) / 4, 0.01));
      expect(back.height, closeTo(back.width * 106 / 78, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a picked card lifts 8 and takes the selection\'s outline; '
        'it shows nothing of what a pick will do', (tester) async {
      Future<(Offset, BoxDecoration)> card({required bool selected}) async {
        await _pump(tester, Center(child: FaceDownCard(selected: selected)));
        await tester.pumpAndSettle();
        final back = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(FaceDownCard),
                matching: find.byType(Container),
              ),
            )
            .firstWhere((c) => c.foregroundDecoration is BoxDecoration);
        return (
          tester.getTopLeft(find.byType(ClipRRect).first),
          back.foregroundDecoration! as BoxDecoration,
        );
      }

      final (restAt, rest) = await card(selected: false);
      final (pickedAt, picked) = await card(selected: true);
      expect(restAt.dy - pickedAt.dy, Space.sm);
      expect((picked.border! as Border).top.color, _skin.night.selection);
      expect((rest.border! as Border).top.color, _skin.night.hairline);
      expect(find.byType(Icon), findsNothing);
    });
  });

  testWidgets('thumbnails keep their mock sizes: 30x40, 50x68', (tester) async {
    await _pump(
      tester,
      const Wrap(
        children: [
          RoleCard(role: RoleId.seer, size: RoleCardSize.thumbSmall),
          RoleCard(role: RoleId.seer, size: RoleCardSize.mini),
        ],
      ),
    );
    expect(
      tester
          .widgetList(find.byType(RoleCard))
          .map((card) => tester.getSize(find.byWidget(card))),
      [const Size(30, 40), const Size(50, 68)],
    );
  });

  testWidgets('a deck card\'s count is 24 tall, set at the 12 label floor', (
    tester,
  ) async {
    await _pump(
      tester,
      const Center(child: CountBadge(2, size: BadgeSize.large)),
    );
    expect(tester.getSize(find.byType(CountBadge)).height, 24);
    expect(tester.widget<Text>(find.text('2')).style!.fontSize, 12);
  });

  testWidgets('the candle panel: padding 10/22/10/10, the number alone', (
    tester,
  ) async {
    await _pump(
      tester,
      const Center(child: WorldTimer.candle(secondsLeft: 19)),
    );
    final panel = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(WorldTimer),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(panel.padding, const EdgeInsets.fromLTRB(10, 10, 22, 10));
    expect(
      find.descendant(of: find.byType(WorldTimer), matching: find.byType(Text)),
      findsOneWidget,
      reason: 'the digits stand alone',
    );
  });

  testWidgets('the night timer: the number in the one timer style, alone', (
    tester,
  ) async {
    await _pump(
      tester,
      const Align(child: WorldTimer.candleCompact(secondsLeft: 14)),
    );
    expect(tester.widget<Text>(find.text('14 s')).style!.fontSize, 64);
    expect(
      find.descendant(of: find.byType(WorldTimer), matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets('preset chips are 44 tall', (tester) async {
    await _pump(
      tester,
      PresetChip(label: 'Classic', selected: false, onTap: () {}),
    );
    expect(tester.getSize(find.byType(PresetChip)).height, 44);
  });

  testWidgets('the vote band runs under the status bar with an 8 px bar and '
      'a 76 number', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: skinTheme(_skin),
        home: ScreenFrame(
          ground: GroundKind.day,
          topSlot: const TimerBand.bar(secondsLeft: 18, remaining: 0.3),
          body: const Text('Who dies today?'),
        ),
      ),
    );
    final band = tester.getRect(find.byType(TimerBand));
    expect(band.top, 0);
    expect(band.width, 390);
    expect(
      tester.getRect(find.text('18 s')).top,
      greaterThan(47),
      reason: 'the number clears the status bar',
    );
    expect(tester.widget<Text>(find.text('18 s')).style!.fontSize, 76);
    // The unit is set smaller than the hero-size number it follows.
    final figure = tester.widget<Text>(find.text('18 s')).textSpan!;
    final unit = (figure as TextSpan).children!.single as TextSpan;
    expect(unit.text, ' s');
    expect(unit.style!.fontSize, lessThan(76 / 2));
    final bar = tester.getRect(
      find.descendant(
        of: find.byType(TimerBand),
        matching: find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ColoredBox),
        ),
      ),
    );
    expect(bar.height, TimerBand.barHeight);
    expect(bar.width, closeTo(390 * 0.3, 0.01));
    expect(
      tester.getRect(find.text('Who dies today?')).top,
      band.bottom + Space.lg,
    );
  });
}
