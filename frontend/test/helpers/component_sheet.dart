import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/section_label.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

// The component sheet: every primitive in lib/design_system/primitives/, in
// each state, on a page per group, on either ground. The screen gallery
// renders it (test_screens/screen_catalogue.dart) and the golden test pins a
// few pages (test/design_system/skin/component_sheet_golden_test.dart).

/// One page of the sheet.
enum ComponentPage {
  buttons,
  players,
  deck,
  card,
  table,
  daylight,
  sheet,
  hold,
  frame,
}

/// Keys the gallery presses and holds to show a pressed or revealed state.
const pressedButtonKey = Key('pressed-primary');
const heldRevealKey = Key('held-reveal');

const _five = [
  TokenId.crow,
  TokenId.key,
  TokenId.moth,
  TokenId.bell,
  TokenId.thorn,
];

/// Pumps [page] on [ground] at the current view size. With [skin] the page is
/// in that skin; without, in the app's chosen skin (the skin switch, as the
/// app does it).
Future<void> pumpComponentPage(
  WidgetTester tester,
  ComponentPage page,
  GroundKind ground, {
  Skin? skin,
}) async {
  final body = ComponentSheetPage(page: page, ground: ground);
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skin == null ? ref.watch(appThemeProvider) : skinTheme(skin),
          home: body,
        ),
      ),
    ),
  );
  await tester.pump();
  switch (page) {
    case ComponentPage.buttons:
      await tester.startGesture(tester.getCenter(find.byKey(pressedButtonKey)));
      await tester.pump(const Duration(milliseconds: 300));
    case ComponentPage.hold:
      await tester.startGesture(tester.getCenter(find.byKey(heldRevealKey)));
      await tester.pump(HoldToReveal.holdDelay * 2);
    default:
  }
}

class ComponentSheetPage extends StatelessWidget {
  const ComponentSheetPage({
    super.key,
    required this.page,
    required this.ground,
  });

  final ComponentPage page;
  final GroundKind ground;

  @override
  Widget build(BuildContext context) => switch (page) {
    ComponentPage.sheet => _SheetPage(ground: ground),
    ComponentPage.frame => _FramePage(ground: ground),
    ComponentPage.daylight => _DaylightPage(ground: ground),
    _ => ScreenFrame(
      ground: ground,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: context.skin.spacing.md,
          children: switch (page) {
            ComponentPage.buttons => _buttons(context),
            ComponentPage.players => _players(context),
            ComponentPage.deck => _deck(context),
            ComponentPage.card => _card(context),
            ComponentPage.table => _table(context),
            ComponentPage.hold => _hold(context),
            ComponentPage.sheet ||
            ComponentPage.frame ||
            ComponentPage.daylight => const [],
          },
        ),
      ),
    ),
  };
}

List<Widget> _buttons(BuildContext context) => [
  const SectionLabel('Primary button', trailing: 'rest · pressed'),
  PrimaryButton(label: 'Deal the cards', onPressed: () {}),
  PrimaryButton(key: pressedButtonKey, label: 'Lock in Cleo', onPressed: () {}),
  const SectionLabel('Busy · disabled'),
  PrimaryButton(label: 'Deal the cards', onPressed: () {}, busy: true),
  const PrimaryButton(label: 'Waiting for players', onPressed: null),
  const SectionLabel('Secondary button', trailing: 'rest · disabled'),
  SecondaryButton(label: 'Do nothing tonight', onPressed: () {}),
  const SecondaryButton(label: 'Change the deck', onPressed: null),
  const SectionLabel('Paper', trailing: 'card · slab'),
  const PaperCard(child: Text('A paper card: plain words in ink.')),
  PaperCard(
    lift: PaperLift.slab,
    child: Row(
      children: [
        Text('TABLE\nCODE', style: context.skin.typography.label),
        const Spacer(),
        Text('K7QX4M', style: context.skin.typography.display),
      ],
    ),
  ),
  const Wrap(
    spacing: 8,
    children: [TagChip('Village team'), TagChip('Werewolf team', danger: true)],
  ),
];

List<Widget> _players(BuildContext context) => [
  const SectionLabel('Tokens', trailing: 'last five not drawn yet'),
  Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [for (final t in TokenId.values) PlayerToken(t)],
  ),
  Row(
    spacing: 10,
    children: [
      for (final t in _five) PlayerToken(t, size: 30, dimmed: t.index > 1),
    ],
  ),
  const SectionLabel('At the table', trailing: '5 players'),
  const PlayerRow(
    token: TokenId.crow,
    name: 'Ana',
    trailing: Text('HOST · YOU'),
  ),
  const PlayerRow(token: TokenId.antler, name: 'Florentyna-Bartholomew'),
  const SectionLabel('Vote'),
  PlayerRow(
    token: TokenId.key,
    name: 'Ben',
    size: PlayerRowSize.large,
    onTap: () {},
  ),
  PlayerRow(
    token: TokenId.moth,
    name: 'Cleo',
    size: PlayerRowSize.large,
    picked: true,
    trailing: const Icon(Icons.close, size: 26),
    onTap: () {},
  ),
  const ProgressPips(done: 3, total: 5, label: '3 of 5 ready'),
  const ProgressPips.tokens(
    tokens: _five,
    done: {TokenId.crow, TokenId.key},
    label: '2 of 5 ready to vote',
  ),
];

const _deckCounts = {
  RoleId.werewolf: 2,
  RoleId.seer: 1,
  RoleId.robber: 1,
  RoleId.troublemaker: 1,
  RoleId.drunk: 1,
  RoleId.villager: 2,
};

/// The deck builder's order (S03).
const _deckOrder = [
  RoleId.werewolf,
  RoleId.minion,
  RoleId.mason,
  RoleId.seer,
  RoleId.robber,
  RoleId.troublemaker,
  RoleId.drunk,
  RoleId.insomniac,
  RoleId.hunter,
  RoleId.tanner,
  RoleId.doppelganger,
  RoleId.villager,
];

List<Widget> _deck(BuildContext context) => [
  const SectionLabel('Deck', trailing: 'lit · dimmed'),
  GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 14,
    crossAxisSpacing: 12,
    childAspectRatio: 0.62,
    children: [
      for (final role in _deckOrder)
        RoleCard(
          role: role,
          count: _deckCounts[role] ?? 0,
          lit: _deckCounts.containsKey(role),
          onTap: () {},
        ),
    ],
  ),
  const SectionLabel('In the deck tonight'),
  Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final MapEntry(key: role, value: count) in _deckCounts.entries)
        RoleCard(role: role, size: RoleCardSize.mini, count: count),
    ],
  ),
];

List<Widget> _card(BuildContext context) => [
  Center(
    child: SizedBox(
      width: 310,
      child: const RoleCard(
        role: RoleId.seer,
        size: RoleCardSize.large,
        team: 'Village team',
        description:
            "Look at one other player's card, or two of the center cards.",
      ),
    ),
  ),
  const SizedBox(height: 8),
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      for (final (role, team) in [
        (RoleId.werewolf, 'Werewolf team'),
        (RoleId.doppelganger, 'Village team'),
      ])
        Expanded(
          child: RoleCard(role: role, size: RoleCardSize.large, team: team),
        ),
    ],
  ),
];

List<Widget> _table(BuildContext context) => [
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Expanded(child: SectionLabel('Night')),
      const WorldTimer.candleCompact(secondsLeft: 14),
    ],
  ),
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FaceDownCard(owner: TokenId.key, ownerName: 'Ben'),
      FaceDownCard(
        owner: TokenId.moth,
        ownerName: 'Cleo',
        selected: true,
        mark: Icons.visibility,
        onTap: () {},
      ),
      const FaceDownCard(owner: TokenId.bell, ownerName: 'Dev'),
      const FaceDownCard(owner: TokenId.hare, ownerName: 'Esme'),
    ],
  ),
  const SectionLabel('Center'),
  const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 22,
    children: [
      FaceDownCard(width: 62),
      FaceDownCard(width: 62),
      FaceDownCard(width: 62),
    ],
  ),
  const SizedBox(height: 8),
  const Center(
    child: WorldTimer.candle(secondsLeft: 19, caption: 'seconds\nof night'),
  ),
  const ProgressPips.tokens(
    tokens: _five,
    done: {TokenId.crow, TokenId.key},
    label: '2 of 5 done',
    tokenSize: 26,
  ),
];

List<Widget> _hold(BuildContext context) => [
  const SectionLabel('Hold to reveal', trailing: 'covered · held'),
  Row(
    spacing: 16,
    children: [
      for (final key in [const Key('covered-reveal'), heldRevealKey])
        Expanded(
          child: HoldToReveal(
            key: key,
            semanticLabel: 'Your card',
            cover: const AspectRatio(
              aspectRatio: FaceDownCard.aspect,
              child: FittedBox(child: FaceDownCard(width: 150)),
            ),
            secret: (_) =>
                const RoleCard(role: RoleId.seer, size: RoleCardSize.large),
          ),
        ),
    ],
  ),
];

class _SheetPage extends StatelessWidget {
  const _SheetPage({required this.ground});

  final GroundKind ground;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Stack(
      children: [
        ScreenFrame(
          ground: ground,
          body: Column(children: _deck(context)),
        ),
        Positioned.fill(child: ColoredBox(color: skin.scrim)),
        Align(
          alignment: Alignment.bottomCenter,
          child: SheetScaffold(
            actions: [
              Expanded(
                child: SecondaryButton(
                  label: 'Take out of deck',
                  onPressed: () {},
                ),
              ),
              PrimaryButton(label: 'Close', onPressed: () {}),
            ],
            child: const _RoleSheetBody(),
          ),
        ),
      ],
    );
  }
}

class _RoleSheetBody extends StatelessWidget {
  const _RoleSheetBody();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: skin.spacing.lg,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: skin.spacing.lg,
          children: [
            const SizedBox(
              width: 132,
              child: RoleCard(
                role: RoleId.troublemaker,
                size: RoleCardSize.small,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: skin.spacing.sm,
                children: [
                  const TagChip('Village team'),
                  FitLine('Troublemaker', style: skin.typography.headline),
                  const SectionLabel('Acts at night'),
                ],
              ),
            ),
          ],
        ),
        Text(
          'Swaps the cards of two other players. Does not look at them.',
          style: skin.typography.bodyLarge,
        ),
      ],
    );
  }
}

class _FramePage extends StatelessWidget {
  const _FramePage({required this.ground});

  final GroundKind ground;

  @override
  Widget build(BuildContext context) {
    final art = context.skin.art;
    return ScreenFrame(
      ground: ground,
      topArt: ground == GroundKind.day ? art.dawnRooftops : art.streetDoor,
      topArtHeight: 330,
      topArtOverlap: 48,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: context.skin.spacing.md,
          children: [
            Text('Midnight Village', style: context.skin.typography.display),
            Text(
              'One table. One night. Somebody is the Werewolf.',
              style: context.skin.typography.bodyLarge.copyWith(
                color: context.ground.quietText,
              ),
            ),
            for (final (i, name) in [
              'Ana',
              'Ben',
              'Cleo',
              'Dev',
              'Esme',
              'Finn',
            ].indexed)
              PlayerRow(token: TokenId.values[i], name: name),
          ],
        ),
      ),
      actions: [
        PrimaryButton(label: 'Start a table', onPressed: () {}),
        SecondaryButton(label: 'Join with a code', onPressed: () {}),
      ],
    );
  }
}

/// The sun timer runs edge to edge, so this page lays itself out.
class _DaylightPage extends StatelessWidget {
  const _DaylightPage({required this.ground});

  final GroundKind ground;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      backgroundColor: skin.ground(ground).ground,
      body: GroundScope(
        ground: ground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WorldTimer.sun(
              secondsLeft: 252,
              elapsed: 0.3,
              caption: 'left to talk',
            ),
            Padding(
              padding: EdgeInsets.all(skin.spacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: skin.spacing.md,
                children: [
                  const SectionLabel('In the deck tonight'),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final MapEntry(key: role, value: count)
                          in _deckCounts.entries)
                        RoleCard(
                          role: role,
                          size: RoleCardSize.mini,
                          count: count,
                        ),
                    ],
                  ),
                  const ProgressPips.tokens(
                    tokens: _five,
                    done: {TokenId.crow, TokenId.key},
                    label: '2 of 5 ready to vote',
                  ),
                  PrimaryButton(label: "I'm ready to vote", onPressed: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
