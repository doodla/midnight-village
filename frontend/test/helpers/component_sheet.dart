import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import 'sheet/day_pages.dart';
import 'sheet/end_pages.dart';
import 'sheet/night_pages.dart';
import 'sheet/sheet_data.dart';
import 'sheet/state_pages.dart';
import 'sheet/table_pages.dart';

// The component sheet: every primitive in lib/design_system/primitives/ in
// each state, and every screen of docs/specs/frontend/first-time-play.md
// rebuilt from them to the spec (its copy, gates and cues), with no literal
// size, colour or font (docs/design/mock-to-skin.md maps each element). A
// page that needs a hold, a tap or a pick gets it the way a player would
// ([ComponentPage.drive]), never by setting the state. The screen gallery
// renders it next to the mocks (test_screens/screen_catalogue.dart); the
// golden test pins a few pages; the contrast, fit and amber tests
// (test/design_system/skin/) measure every page in every skin.

/// One page of the sheet. A screen page rebuilds a screen of the spec in one
/// state, on its own ground; a state page shows primitives in each state.
enum ComponentPage {
  // State pages.
  buttons,
  players,
  gates(grounds: [GroundKind.night, GroundKind.day]),
  facesCard(grounds: [GroundKind.night]),
  facesNight(grounds: [GroundKind.night]),
  // Screen pages: each with its mock, on its mock's ground, as the phone of
  // a recorded game ([Viewer]) had it.
  join(mock: '01-join.png'),
  joinCode(mock: '01-join.png'),
  table(mock: '02-table.png'),
  tableGuest(mock: '02-table.png'),
  deck(mock: '03-deck.png'),
  sheet(mock: '03b-deck-role-explained.png'),
  card(mock: '04-your-card.png'),
  cardHeld(mock: '04-your-card.png'),
  cardHeldVillager(mock: '04-your-card.png', viewer: Viewer.villager),
  wait(mock: '05-night-waiting.png'),
  action(mock: '06-night-action.png'),
  actionHeld(mock: '06-night-action.png'),
  actionHeldVillager(mock: '06-night-action.png', viewer: Viewer.villager),
  actionPicked(mock: '06-night-action.png'),
  actionOneMore(mock: '06-night-action.png'),
  actionTwoPicks(mock: '06-night-action.png'),
  actionChosen(mock: '06-night-action.png'),
  actionNotSent(mock: '06-night-action.png'),
  actionFollowUpHeld(
    mock: '06-night-action.png',
    viewer: Viewer.doppelgangerFollowUp,
  ),
  actionNine(mock: '06-night-action.png', viewer: Viewer.drunk),
  actionNineLarge(mock: '06-night-action.png', viewer: Viewer.drunk),
  actionThree(mock: '06-night-action.png'),
  actionTenLong(mock: '06-night-action.png', viewer: Viewer.drunk),
  talk(mock: '08-talk.png', day: true),
  talkHeld(mock: '08-talk.png', day: true),
  talkRobber(mock: '08-talk.png', day: true, viewer: Viewer.robber),
  talkLoneWerewolf(mock: '08-talk.png', day: true, viewer: Viewer.loneWerewolf),
  talkDrunk(mock: '08-talk.png', day: true, viewer: Viewer.drunk),
  talkDoppelganger(mock: '08-talk.png', day: true, viewer: Viewer.doppelganger),
  vote(mock: '09-vote.png', day: true),
  votePicked(mock: '09-vote.png', day: true),
  voteLocked(mock: '09-vote.png', day: true),
  count(mock: '10-the-count.png', day: true),
  results(mock: '11-results.png'),
  resultsGuest(mock: '11-results.png'),
  countMoved(mock: '10-the-count.png', day: true),
  countNobody(mock: '10-the-count.png', day: true),
  countTenLong(mock: '10-the-count.png', day: true),
  resultsWerewolves(mock: '11-results.png', viewer: Viewer.villager),
  resultsTanner(mock: '11-results.png'),
  resultsTenLong(mock: '11-results.png');

  const ComponentPage({
    this.mock,
    this.day = false,
    this.viewer = Viewer.seer,
    List<GroundKind>? grounds,
  }) : _grounds = grounds;

  /// The mock this page rebuilds, in docs/design/mocks/.
  final String? mock;
  final bool day;

  /// Whose phone the page is (game 7's Seer, Ana, unless it says).
  final Viewer viewer;
  final List<GroundKind>? _grounds;

  /// A page a player sees: held to the reading floor by the gallery.
  bool get playerScreen => mock != null;

  /// The grounds this page is drawn on: a screen on its own; a state page
  /// on each it is meant for.
  List<GroundKind> get grounds => playerScreen
      ? [if (day) GroundKind.day else GroundKind.night]
      : _grounds ?? GroundKind.values;

  /// What a phone in its first game has learned by this page, alone on the
  /// sheet: the hold on 04, "You" and the board's wave on 06, My night on
  /// 08. A journey (the cold-read pack) passes what it has really learned.
  Set<Cue> get learned => switch (this) {
    card || cardHeld || cardHeldVillager || gates => const {},
    talk ||
    talkHeld ||
    talkRobber ||
    talkLoneWerewolf ||
    talkDrunk ||
    talkDoppelganger => {...Cue.values}..remove(Cue.holdMyNight),
    action ||
    actionHeld ||
    actionHeldVillager ||
    actionPicked ||
    actionOneMore ||
    actionTwoPicks ||
    actionChosen ||
    actionNotSent ||
    actionFollowUpHeld ||
    actionNine ||
    actionNineLarge ||
    actionThree ||
    actionTenLong => const {Cue.hold},
    _ => Cue.values.toSet(),
  };

  /// What a player learns by doing what [drive] does here.
  Set<Cue> get teaches => switch (this) {
    cardHeld || cardHeldVillager => const {Cue.hold},
    actionHeld ||
    actionHeldVillager ||
    actionFollowUpHeld => const {Cue.hold, Cue.holdYou},
    actionChosen => const {Cue.nightChoose},
    talkHeld ||
    talkRobber ||
    talkLoneWerewolf ||
    talkDrunk ||
    talkDoppelganger => const {Cue.hold, Cue.holdMyNight},
    voteLocked => const {Cue.voteLock},
    _ => const {},
  };

  /// Puts the page in its state as a player would: a press, a hold, taps,
  /// on [viewer]'s phone (this page's own unless given).
  Future<void> drive(WidgetTester tester, [Viewer? viewer]) async {
    final who = viewer ?? this.viewer;
    Future<void> tapAll(Iterable<String> captions) async {
      for (final caption in captions) {
        await tester.tap(find.text(caption).last);
        await tester.pump();
      }
    }

    switch (this) {
      case buttons:
        await tester.startGesture(tester.getCenter(find.byKey(pressedKey)));
        await tester.pump(const Duration(milliseconds: 300));
      case cardHeld || cardHeldVillager:
        await holdDown(tester, find.byType(FaceDownCard));
      case actionHeld || actionHeldVillager || actionFollowUpHeld:
        await holdDown(tester, _you);
      case talkHeld || talkRobber || talkLoneWerewolf || talkDrunk:
        await holdDown(tester, find.byType(PeekBox));
      case talkDoppelganger:
        // The second hold shows My night's second page: window 1's.
        await holdAndLetGo(tester, find.byType(PeekBox));
        await holdDown(tester, find.byType(PeekBox));
      case actionPicked:
        await tapAll(who.taps);
      case actionOneMore:
        await tapAll([NightCopy.left]);
      case actionTwoPicks:
        await tapAll([NightCopy.left, NightCopy.right]);
      case actionChosen:
        await tapAll(who.taps);
        await tester.tap(find.byType(PrimaryButton));
      case actionNotSent:
        await tapAll(who.taps);
        await tester.tap(find.byType(PrimaryButton));
        await tester.pump();
      case votePicked:
        await tester.tap(find.text(cleo.name));
      case voteLocked:
        await tester.tap(find.text(cleo.name));
        await tester.pump();
        await tester.tap(find.byType(PrimaryButton));
      case gates:
        await tester.tap(find.byKey(replayedGateKey));
      default:
    }
    await tester.pump();
  }
}

/// Keys the sheet presses: the pressed primary button, the gate tapped to
/// replay its cue.
const pressedKey = Key('pressed-primary');
const replayedGateKey = Key('replayed-gate');

/// "You" on the night board.
final _you = find.ancestor(
  of: find.text(NightCopy.you),
  matching: find.byType(FaceDownCard),
);

/// Presses [target] and keeps holding past the 0.8 s that counts a reveal.
Future<TestGesture> holdDown(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target.first));
  await tester.pump(HoldToReveal.holdDelay);
  await tester.pump(HoldToReveal.revealedAfter);
  return gesture;
}

/// Holds [target] long enough for the reveal to count, then lets go.
Future<void> holdAndLetGo(WidgetTester tester, Finder target) async {
  final gesture = await holdDown(tester, target);
  await gesture.up();
  await tester.pump();
}

/// Learned cues kept in memory: the sheet never writes to the device.
class _Forgetful extends DevicePreferences {
  @override
  Future<void> setFlag(String key) async {}

  @override
  Future<void> clearFlags(String prefix) async {}
}

/// [learned] as this device's history.
class SheetLearned extends LearnedCues {
  SheetLearned(this.learned);

  final Set<Cue> learned;

  @override
  Set<Cue> build() => learned;
}

/// The overrides that give a sheet page its device history.
List<Override> learnedOverrides(Set<Cue> learned) => [
  devicePreferencesProvider.overrideWithValue(_Forgetful()),
  learnedCuesProvider.overrideWith(() => SheetLearned(learned)),
];

/// Pumps [page] on [ground] at the current view size, then drives it to its
/// state. With [skin] the page is in that skin; without, in the app's chosen
/// skin (as the app does it).
Future<void> pumpComponentPage(
  WidgetTester tester,
  ComponentPage page,
  GroundKind ground, {
  Skin? skin,
  Viewer? viewer,
  Set<Cue>? learned,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(learned ?? page.learned),
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skin == null ? ref.watch(appThemeProvider) : skinTheme(skin),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: ComponentSheetPage(
            page: page,
            ground: ground,
            viewer: viewer ?? page.viewer,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await page.drive(tester, viewer);
}

class ComponentSheetPage extends StatelessWidget {
  const ComponentSheetPage({
    super.key,
    required this.page,
    required this.ground,
    required this.viewer,
  });

  final ComponentPage page;
  final GroundKind ground;

  /// Whose phone it is.
  final Viewer viewer;

  @override
  Widget build(BuildContext context) => switch (page) {
    ComponentPage.buttons => ButtonsPage(ground: ground),
    ComponentPage.players => PlayersPage(ground: ground),
    ComponentPage.gates => GatesPage(ground: ground),
    ComponentPage.facesCard => const FacesPage(night: false),
    ComponentPage.facesNight => const FacesPage(night: true),
    ComponentPage.join => const JoinPage(),
    ComponentPage.joinCode => const JoinPage(code: true),
    ComponentPage.table => const TablePage(),
    ComponentPage.tableGuest => const TablePage(guest: true),
    ComponentPage.deck => const DeckPage(),
    ComponentPage.sheet => const RoleSheetPage(),
    ComponentPage.card ||
    ComponentPage.cardHeld ||
    ComponentPage.cardHeldVillager => CardPage(viewer: viewer),
    ComponentPage.wait => const WaitPage(),
    ComponentPage.action ||
    ComponentPage.actionHeld ||
    ComponentPage.actionHeldVillager ||
    ComponentPage.actionPicked ||
    ComponentPage.actionOneMore ||
    ComponentPage.actionTwoPicks ||
    ComponentPage.actionChosen ||
    ComponentPage.actionFollowUpHeld ||
    ComponentPage.actionNine => BoardPage(viewer: viewer),
    ComponentPage.actionNotSent => BoardPage(viewer: viewer, fails: true),
    ComponentPage.actionNineLarge => BoardPage(viewer: viewer, textScale: 2),
    // Three at the table: game 7 without Dev and Esme.
    ComponentPage.actionThree => BoardPage(
      viewer: viewer,
      table: (me) => tableOf(me, leave: {dev.name, esme.name}),
    ),
    // Ten at the table, as many as the server seats, with long names.
    ComponentPage.actionTenLong => BoardPage(
      viewer: viewer,
      table: (me) => tableOf(me, add: 1, rename: longNames),
    ),
    ComponentPage.talk ||
    ComponentPage.talkHeld ||
    ComponentPage.talkRobber ||
    ComponentPage.talkLoneWerewolf ||
    ComponentPage.talkDrunk ||
    ComponentPage.talkDoppelganger => TalkPage(viewer: viewer),
    ComponentPage.vote ||
    ComponentPage.votePicked ||
    ComponentPage.voteLocked => const VotePage(),
    ComponentPage.count => const CountPage(),
    ComponentPage.results => ResultsPage(viewer: viewer),
    ComponentPage.resultsGuest => ResultsPage(viewer: viewer, guest: true),
    ComponentPage.countMoved => const CountPage(game: EndGame.werewolves),
    ComponentPage.countNobody => const CountPage(game: EndGame.nobody),
    ComponentPage.countTenLong => const CountPage(game: EndGame.tenLong),
    ComponentPage.resultsWerewolves => ResultsPage(
      viewer: viewer,
      game: EndGame.werewolves,
      guest: true,
    ),
    ComponentPage.resultsTanner => ResultsPage(
      viewer: viewer,
      game: EndGame.tanner,
      guest: true,
    ),
    ComponentPage.resultsTenLong => ResultsPage(
      viewer: viewer,
      game: EndGame.tenLong,
      guest: true,
    ),
  };
}
