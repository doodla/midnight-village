import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/count_badge.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
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
import 'package:midnight_village/design_system/primitives/skin_field.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skin_tilt.dart';

import 'painted_text.dart';

// The component sheet: every primitive in lib/design_system/primitives/, in
// each state, and every mock screen rebuilt from them with no literal size,
// colour or font (docs/design/mock-to-skin.md maps each element). The screen
// gallery renders it next to the mocks (test_screens/screen_catalogue.dart);
// the golden test pins a few pages; the contrast and fit sweeps
// (test/design_system/skin/) measure every page in every skin.

/// One page of the sheet. A mock page rebuilds that mock on its own ground;
/// a state page shows each primitive in each state, on any ground.
enum ComponentPage {
  // State pages.
  buttons,
  players,
  hold,
  // Mock pages, with the ground of their mock.
  join(mock: '01-join.png', ground: GroundKind.night),
  table(mock: '02-table.png', ground: GroundKind.night),
  deck(mock: '03-deck.png', ground: GroundKind.night),
  sheet(mock: '03b-deck-role-explained.png', ground: GroundKind.night),
  card(mock: '04-your-card.png', ground: GroundKind.night),
  wait(mock: '05-night-waiting.png', ground: GroundKind.night),
  action(mock: '06-night-action.png', ground: GroundKind.night),
  saw(mock: '07-night-what-you-saw.png', ground: GroundKind.night),
  talk(mock: '08-talk.png', ground: GroundKind.day),
  vote(mock: '09-vote.png', ground: GroundKind.day),
  count(mock: '10-the-count.png', ground: GroundKind.day),
  results(mock: '11-results.png', ground: GroundKind.night);

  const ComponentPage({this.mock, this.ground});

  /// The mock this page rebuilds, in docs/design/mocks/.
  final String? mock;

  /// A mock page's own ground; null for a state page.
  final GroundKind? ground;

  /// The grounds this page is drawn on.
  List<GroundKind> get grounds =>
      [?ground].isEmpty ? GroundKind.values : [ground!];
}

/// Keys the sheet presses and holds to show a pressed or revealed state.
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
/// in that skin; without, in the app's chosen skin (as the app does it).
Future<void> pumpComponentPage(
  WidgetTester tester,
  ComponentPage page,
  GroundKind ground, {
  Skin? skin,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skin == null ? ref.watch(appThemeProvider) : skinTheme(skin),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: ComponentSheetPage(page: page, ground: ground),
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
    ComponentPage.buttons => _StatePage(ground: ground, children: _buttons),
    ComponentPage.players => _StatePage(ground: ground, children: _players),
    ComponentPage.hold => _StatePage(ground: ground, children: _hold),
    ComponentPage.join => const _Join(),
    ComponentPage.table => const _Table(),
    ComponentPage.deck => const _Deck(),
    ComponentPage.sheet => const _Sheet(),
    ComponentPage.card => const _Card(),
    ComponentPage.wait => const _Wait(),
    ComponentPage.action => const _Action(),
    ComponentPage.saw => const _Saw(),
    ComponentPage.talk => const _Talk(),
    ComponentPage.vote => const _Vote(),
    ComponentPage.count => const _Count(),
    ComponentPage.results => const _Results(),
  };
}

class _StatePage extends StatelessWidget {
  const _StatePage({required this.ground, required this.children});

  final GroundKind ground;
  final List<Widget> Function(BuildContext) children;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: ground,
    body: Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.md,
        children: children(context),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// State pages
// ---------------------------------------------------------------------------

List<Widget> _buttons(BuildContext context) => [
  const SectionLabel('Primary', trailing: 'large · pressed'),
  PrimaryButton(
    label: 'Start a table',
    onPressed: () {},
    size: ButtonSize.large,
  ),
  PrimaryButton(key: pressedButtonKey, label: 'Lock in Cleo', onPressed: () {}),
  const SectionLabel('Busy · disabled'),
  PrimaryButton(label: 'Deal the cards', onPressed: () {}, busy: true),
  const PrimaryButton(label: 'Waiting for players', onPressed: null),
  const SectionLabel('Secondary', trailing: 'rest · off'),
  SecondaryButton(label: 'Do nothing tonight', onPressed: () {}),
  const SecondaryButton(label: 'Change the deck', onPressed: null),
  Row(
    spacing: Space.smPlus,
    children: [
      Expanded(
        child: SecondaryButton(
          label: 'Take out of deck',
          onPressed: () {},
          size: ButtonSize.compact,
        ),
      ),
      PrimaryButton(label: 'Close', onPressed: () {}, size: ButtonSize.compact),
    ],
  ),
  Align(
    alignment: Alignment.centerRight,
    child: SecondaryButton.paper(label: 'Join', onPressed: () {}),
  ),
  const SectionLabel('Paper · tags · chips'),
  const PaperCard(child: Text('A paper card: plain words in ink.')),
  const Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      TagChip('Village team'),
      TagChip.danger('Werewolf team'),
      TagChip('Village team', small: true),
      Pill('8 of 8 cards', icon: Icons.check),
      Pill('Night one', icon: Icons.nightlight_round, lifted: true),
      StatusDot(),
      CountBadge('×2'),
      CountBadge('2', size: BadgeSize.large),
    ],
  ),
  Wrap(
    spacing: Space.sm,
    children: [
      PresetChip(label: 'First game', selected: true, onTap: () {}),
      PresetChip(label: 'Classic', selected: false, onTap: () {}),
    ],
  ),
  const InsetPanel(child: Text('Wins if a Werewolf dies.')),
];

List<Widget> _players(BuildContext context) => [
  const SectionLabel('Tokens', trailing: 'drawn · waiting · unknown'),
  Wrap(
    spacing: Space.smPlus,
    runSpacing: Space.smPlus,
    children: [
      for (final t in TokenId.values) PlayerToken(t),
      const PlayerToken(null),
    ],
  ),
  Row(
    spacing: Space.smPlus,
    children: [
      for (final t in _five)
        PlayerToken(t, size: TokenSize.pip, waiting: t.index > 1),
    ],
  ),
  const SectionLabel('Rows', trailing: 'compact · large · count'),
  const PlayerRow(
    token: TokenId.crow,
    name: 'Ana',
    trailing: RowNote('Host · you'),
  ),
  const PlayerRow(token: TokenId.antler, name: 'Florentyna-Bartholomew'),
  PlayerRow(
    token: TokenId.moth,
    name: 'Cleo',
    size: PlayerRowSize.large,
    picked: true,
    trailing: const Icon(Icons.close, size: 26),
    onTap: () {},
  ),
  const PlayerRow(
    token: TokenId.bell,
    name: 'Dev',
    size: PlayerRowSize.count,
    picked: true,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.md,
      children: [
        VoterTokens([TokenId.crow, TokenId.key, TokenId.moth]),
        Tally(3),
      ],
    ),
  ),
  const ProgressPips(done: 3, total: 5, label: '3 of 5 ready'),
  const ProgressPips.tokens(
    tokens: _five,
    done: {TokenId.crow, TokenId.key},
    label: '2 of 5 ready to vote',
  ),
];

List<Widget> _hold(BuildContext context) => [
  const SectionLabel('Hold to reveal', trailing: 'covered · held'),
  Row(
    spacing: Space.lg,
    children: [
      for (final key in [const Key('covered-reveal'), heldRevealKey])
        Expanded(
          child: HoldToReveal(
            key: key,
            semanticLabel: 'Your card',
            cover: const FaceDownCard(size: FaceDownSize.hero),
            secret: (_) => const RoleCard(
              role: RoleId.seer,
              size: RoleCardSize.large,
              team: 'Village team',
            ),
          ),
        ),
    ],
  ),
  HoldToReveal(
    semanticLabel: 'My night',
    cover: const PeekBox(title: 'My night', hint: 'Hold to peek'),
    secret: (_) => const Text('You slept through the night.'),
  ),
];

// ---------------------------------------------------------------------------
// Mock pages
// ---------------------------------------------------------------------------

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

/// Tonight's deck as a row of thumbnails, which shrink to fit the row.
Widget _deckRow(RoleCardSize size) => Row(
  spacing: size == RoleCardSize.thumbSmall ? Space.sm : Space.smPlus,
  children: [
    for (final MapEntry(key: role, value: count) in _deckCounts.entries)
      Flexible(
        child: RoleCard(role: role, size: size, count: count),
      ),
  ],
);

class _Join extends StatelessWidget {
  const _Join();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.streetDoor,
      body: Builder(
        builder: (context) {
          final quiet = context.ground.quietText;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.lgPlus,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Space.xs,
                children: [
                  FitLine('Midnight Village', style: type.heroTitle),
                  Text(
                    'One table. One night. Somebody is the Werewolf.',
                    style: type.lede.copyWith(color: quiet),
                  ),
                ],
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Space.sm,
                children: [
                  SectionLabel('Your name'),
                  SkinField.paper(semanticLabel: 'Your name', hint: 'Ana'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: Space.mdPlus,
                children: [
                  PrimaryButton(
                    label: 'Start a table',
                    onPressed: () {},
                    size: ButtonSize.large,
                  ),
                  Row(
                    spacing: Space.smPlus,
                    children: [
                      const Expanded(
                        child: SkinField.code(
                          semanticLabel: 'Table code',
                          hint: 'Table code',
                        ),
                      ),
                      SecondaryButton.paper(label: 'Join', onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.xs,
            children: [
              const Divider(height: Space.mdPlus),
              for (final line in [
                '23 players at 5 tables tonight',
                'Your last game: the village won · 6 players · yesterday',
              ])
                Text(
                  line,
                  style: type.small.copyWith(color: context.ground.quietText),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.table,
      topArtLayout: TopArtLayout.banner,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.md,
        children: [
          PaperCard(
            lift: PaperLift.slab,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            child: Builder(
              builder: (context) => Row(
                spacing: Space.md,
                children: [
                  Text(
                    'TABLE\nCODE',
                    style: type.label.copyWith(color: context.ground.quietText),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FitLine('K7QX4M', style: type.heroCode),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.sm,
              children: [
                const SectionLabel('At the table', trailing: '5 players'),
                const PlayerRow(
                  token: TokenId.crow,
                  name: 'Ana',
                  trailing: RowNote('Host · you'),
                ),
                for (final (token, name) in [
                  (TokenId.key, 'Ben'),
                  (TokenId.moth, 'Cleo'),
                  (TokenId.bell, 'Dev'),
                  (TokenId.thorn, 'Esme'),
                ])
                  PlayerRow(token: token, name: name),
              ],
            ),
          ),
          OutlinePanel(
            onTap: () {},
            semanticLabel: 'Tonight\'s deck, 8 cards. Change',
            child: Builder(
              builder: (context) => Row(
                spacing: Space.smPlus,
                children: [
                  Expanded(child: _deckRow(RoleCardSize.thumbSmall)),
                  Text.rich(
                    textAlign: TextAlign.right,
                    TextSpan(
                      text: '8 cards\n',
                      style: type.tag.copyWith(height: 1.3),
                      children: [
                        TextSpan(
                          text: 'Change',
                          style: TextStyle(color: context.ground.selection),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [PrimaryButton(label: 'Deal the cards', onPressed: () {})],
    );
  }
}

class _DeckBody extends StatelessWidget {
  const _DeckBody({this.withControls = true});

  final bool withControls;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.mdPlus,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: Space.md,
          children: [
            Expanded(child: FitLine("Tonight's deck", style: type.headline)),
            const Pill('8 of 8 cards', icon: Icons.check),
          ],
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final (i, label) in ['First game', 'Classic', 'Chaos'].indexed)
              PresetChip(label: label, selected: i == 0, onTap: () {}),
          ],
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.mdPlus,
          crossAxisSpacing: Space.md,
          childAspectRatio: 0.62,
          padding: const EdgeInsets.only(top: Space.xxs),
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
        if (withControls) ...[
          Text(
            'Tap to add or remove. Hold a card to read what it does.',
            style: type.caption.copyWith(color: context.ground.quietText),
          ),
          const SectionLabel('Pace'),
          // Four tiles that share the row and grow with their text.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.sm,
              children: [
                for (final (label, value) in [
                  ('Talk', '5:00'),
                  ('Vote', '1:00'),
                  ('Night', '30s'),
                  ('Double', '10s'),
                ])
                  Expanded(
                    child: PaceTile(label: label, value: value, onTap: () {}),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Deck extends StatelessWidget {
  const _Deck();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: const _DeckBody(),
    actions: [PrimaryButton(label: 'Use this deck', onPressed: () {})],
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Stack(
      children: [
        const BehindScrim(
          child: ScreenFrame(
            ground: GroundKind.night,
            body: _DeckBody(withControls: false),
          ),
        ),
        Positioned.fill(child: ColoredBox(color: skin.scrim)),
        Align(
          alignment: Alignment.bottomCenter,
          child: GroundScope(
            ground: GroundKind.night,
            child: SheetScaffold(
              actions: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Take out of deck',
                    onPressed: () {},
                    size: ButtonSize.compact,
                  ),
                ),
                PrimaryButton(
                  label: 'Close',
                  onPressed: () {},
                  size: ButtonSize.compact,
                ),
              ],
              child: const _RoleSheetBody(),
            ),
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
    final type = context.skin.typography;
    final ink = TextStyle(
      color: context.ground.text,
      fontWeight: type.smallStrong.fontWeight,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.lg,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: Space.lg,
          children: [
            const RolePortrait(
              role: RoleId.troublemaker,
              width: RolePortrait.sheet,
              framed: true,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.sm,
                children: [
                  const TagChip('Village team', small: true),
                  FitLine('Troublemaker', style: type.headline),
                  const SectionLabel('Acts at night'),
                ],
              ),
            ),
          ],
        ),
        Text(
          'Swaps the cards of two other players. Does not look at them. '
          'Neither player is told.',
          style: type.bodyLarge,
        ),
        InsetPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.sm,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Wins', style: ink),
                    const TextSpan(text: ' if a Werewolf dies.'),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Good with', style: ink),
                    const TextSpan(text: ' Seer, Robber, Insomniac.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.nightVillage,
      topArtLayout: TopArtLayout.backdrop,
      body: Column(
        spacing: Space.lgPlus,
        children: [
          const Pill(
            'Night one · your card',
            icon: Icons.nightlight_round,
            lifted: true,
          ),
          const RoleCard(
            role: RoleId.seer,
            size: RoleCardSize.large,
            team: 'Village team',
            description:
                "Look at one other player's card, or two of the center cards.",
          ),
          const SizedBox(height: Space.xxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Space.smPlus,
            children: [
              const StatusDot(),
              Flexible(
                child: Text(
                  'Holding. Let go and the card turns face down.',
                  style: skin.typography.body,
                ),
              ),
            ],
          ),
        ],
      ),
      actionGap: Space.lg,
      actions: [
        PrimaryButton(
          label: 'I know my card',
          onPressed: () {},
          size: ButtonSize.large,
        ),
        const ProgressPips(
          done: 3,
          total: 5,
          label: '3 of 5 ready',
          centred: true,
        ),
      ],
    );
  }
}

class _Wait extends StatelessWidget {
  const _Wait();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.sleepingVillage,
      body: Builder(
        builder: (context) => Column(
          spacing: Space.lgPlus,
          children: [
            Text(
              'The village sleeps',
              textAlign: TextAlign.center,
              style: type.screenTitle,
            ),
            const WorldTimer.candle(
              secondsLeft: 19,
              caption: 'seconds\nof night',
            ),
            const SizedBox(height: Space.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: Space.lgPlus,
              children: [
                for (var i = 0; i < 3; i++)
                  Flexible(
                    child: FaceDownCard(
                      size: FaceDownSize.scatter,
                      tilt: Tilt.scatter(i),
                      semanticLabel: 'Face-down card ${i + 1}',
                      onTap: () {},
                    ),
                  ),
              ],
            ),
            Text(
              'Tap the cards while you wait',
              style: type.body.copyWith(color: context.ground.quietText),
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (context) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Space.smPlus,
            children: [
              const PlayerToken(
                TokenId.bell,
                size: TokenSize.waiting,
                waiting: true,
              ),
              Flexible(
                child: Text(
                  'Waiting for Dev to reconnect',
                  style: type.small.copyWith(color: context.ground.quietText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action();

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.md,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  spacing: Space.smPlus,
                  children: [
                    const RoleCard(role: RoleId.seer, size: RoleCardSize.thumb),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Your turn'),
                          FitLine('Seer', style: type.title),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const WorldTimer.candleCompact(secondsLeft: 14),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: Text(
              "Look at one player's card, or two from the center.",
              style: type.title,
            ),
          ),
          const SizedBox(height: Space.mdPlus),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.xs,
            children: [
              for (final (token, name) in [
                (TokenId.key, 'Ben'),
                (TokenId.moth, 'Cleo'),
                (TokenId.bell, 'Dev'),
                (TokenId.thorn, 'Esme'),
              ])
                Expanded(
                  child: FaceDownCard(
                    owner: token,
                    ownerName: name,
                    selected: name == 'Cleo',
                    mark: Icons.visibility,
                    semanticLabel: "$name's card",
                    onTap: () {},
                  ),
                ),
            ],
          ),
          const Divider(height: Space.xl),
          const SectionLabel('Center', centred: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Space.xl,
            children: [
              for (final side in ['Left', 'Middle', 'Right'])
                Flexible(
                  child: FaceDownCard(
                    size: FaceDownSize.center,
                    caption: side,
                    recessed: true,
                    semanticLabel: '$side center card',
                    onTap: () {},
                  ),
                ),
            ],
          ),
        ],
      ),
      actionGap: Space.md,
      actions: [
        PrimaryButton(label: "Look at Cleo's card", onPressed: () {}),
        SecondaryButton(label: 'Do nothing tonight', onPressed: () {}),
      ],
    );
  }
}

class _Saw extends StatelessWidget {
  const _Saw();

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      body: Column(
        spacing: Space.mdPlus,
        children: [
          Column(
            spacing: Space.smPlus,
            children: [
              const SectionLabel('You looked at', centred: true),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: Space.md,
                children: [
                  const PlayerToken(TokenId.moth, size: TokenSize.header),
                  Flexible(child: FitLine("Cleo's card", style: type.display)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.mdPlus),
          HoldToReveal(
            semanticLabel: "Cleo's card",
            cover: const FaceDownCard(
              size: FaceDownSize.hero,
              holdHint: 'Hold to flip',
            ),
            secret: (_) => const RoleCard(
              role: RoleId.werewolf,
              size: RoleCardSize.large,
              team: 'Werewolf team',
            ),
          ),
        ],
      ),
      actions: [
        PrimaryButton(label: 'Done', onPressed: () {}),
        const ProgressPips.tokens(
          tokens: _five,
          done: {TokenId.crow, TokenId.key},
          label: '2 of 5 done',
          tokenSize: TokenSize.waiting,
          centred: true,
        ),
      ],
    );
  }
}

class _Talk extends StatelessWidget {
  const _Talk();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.day,
    topSlot: const TimerBand.sun(
      secondsLeft: 252,
      elapsed: 0.3,
      caption: 'left to talk',
    ),
    body: Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lg,
        children: [
          HoldToReveal(
            semanticLabel: 'My night',
            cover: const PeekBox(title: 'My night', hint: 'Hold to peek'),
            secret: (_) => const Text('You slept through the night.'),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.smPlus,
            children: [
              const SectionLabel('In the deck tonight'),
              _deckRow(RoleCardSize.mini),
            ],
          ),
        ],
      ),
    ),
    actions: [
      const ProgressPips.tokens(
        tokens: _five,
        done: {TokenId.crow, TokenId.key},
        label: '2 of 5 ready to vote',
      ),
      PrimaryButton(label: "I'm ready to vote", onPressed: () {}),
    ],
  );
}

class _Vote extends StatelessWidget {
  const _Vote();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.day,
    topSlot: const TimerBand.bar(
      secondsLeft: 18,
      remaining: 0.3,
      caption: 'seconds to choose',
    ),
    body: Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.md,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Space.xs, bottom: Space.xxs),
            child: Text(
              'Who dies today?',
              style: context.skin.typography.screenTitle,
            ),
          ),
          for (final (token, name) in [
            (TokenId.key, 'Ben'),
            (TokenId.moth, 'Cleo'),
            (TokenId.bell, 'Dev'),
            (TokenId.thorn, 'Esme'),
          ])
            PlayerRow(
              token: token,
              name: name,
              size: PlayerRowSize.large,
              picked: name == 'Cleo',
              trailing: name == 'Cleo'
                  ? const Icon(Icons.close, semanticLabel: 'Your pick')
                  : null,
              onTap: () {},
            ),
        ],
      ),
    ),
    actions: [
      const ProgressPips.tokens(
        tokens: [
          TokenId.key,
          TokenId.bell,
          TokenId.thorn,
          TokenId.crow,
          TokenId.moth,
        ],
        done: {TokenId.key, TokenId.bell, TokenId.thorn},
        label: '3 of 5 locked in',
      ),
      PrimaryButton(label: 'Lock in Cleo', onPressed: () {}),
    ],
  );
}

class _Count extends StatelessWidget {
  const _Count();

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: Band(
        child: Builder(
          builder: (context) => Row(
            spacing: Space.lg,
            children: [
              PlayerToken(
                TokenId.bell,
                size: TokenSize.band,
                ringColor: context.ground.dangerLine,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.xxs,
                  children: [
                    const SectionLabel('The count'),
                    FitLine('Dev dies.', style: type.heroVerdict),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.smPlus,
        children: [
          const SectionLabel('Accused', trailing: 'Voted by'),
          for (final (token, name, voters) in [
            (TokenId.bell, 'Dev', [TokenId.crow, TokenId.key, TokenId.moth]),
            (TokenId.moth, 'Cleo', [TokenId.bell]),
            (TokenId.crow, 'Ana', [TokenId.thorn]),
          ])
            PlayerRow(
              token: token,
              name: name,
              size: PlayerRowSize.count,
              picked: name == 'Dev',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.md,
                children: [VoterTokens(voters), Tally(voters.length)],
              ),
            ),
          const SizedBox(height: Space.sm),
          PaperCard(
            lift: PaperLift.heroSlab,
            padding: const EdgeInsets.all(Space.smPlus),
            child: Builder(
              builder: (context) => Row(
                spacing: Space.lg,
                children: [
                  const RolePortrait(
                    role: RoleId.werewolf,
                    width: RolePortrait.count,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: Space.sm,
                      children: [
                        const SectionLabel('Dev was the'),
                        FitLine('Werewolf', style: type.display),
                        const TagChip.danger('Werewolf team'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [PrimaryButton(label: 'See who won', onPressed: () {})],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results();

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      topSlot: Band(
        tone: BandTone.danger,
        child: Row(
          spacing: Space.lg,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const RolePortrait.arched(
              role: RoleId.werewolf,
              width: RolePortrait.winner,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.md,
                children: [
                  const TagChip('Cleo held the Robber', tone: TagTone.ground),
                  FitWords('The Werewolf wins', style: type.heroWinner),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) => Text(
          'Each column is a player. The red line is the Werewolf card.\n'
          'Center cards, untouched: Werewolf · Drunk · Insomniac',
          style: type.caption.copyWith(color: context.ground.quietText),
        ),
      ),
      actions: [
        Row(
          spacing: Space.md,
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Play again',
                onPressed: () {},
                size: ButtonSize.large,
              ),
            ),
            Expanded(
              child: SecondaryButton(
                label: 'Change the deck',
                onPressed: () {},
                size: ButtonSize.large,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
