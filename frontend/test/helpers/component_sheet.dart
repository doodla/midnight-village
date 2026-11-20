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
  // Screen pages: each with its mock, on its mock's ground.
  join(mock: '01-join.png'),
  joinCode(mock: '01-join.png'),
  table(mock: '02-table.png'),
  tableGuest(mock: '02-table.png'),
  deck(mock: '03-deck.png'),
  sheet(mock: '03b-deck-role-explained.png'),
  card(mock: '04-your-card.png'),
  cardHeld(mock: '04-your-card.png', viewer: Viewer.seer),
  cardHeldVillager(mock: '04-your-card.png', viewer: Viewer.villager),
  wait(mock: '05-night-waiting.png'),
  action(mock: '06-night-action.png'),
  actionHeld(mock: '06-night-action.png', viewer: Viewer.seer),
  actionHeldVillager(mock: '06-night-action.png', viewer: Viewer.villager),
  actionPicked(mock: '06-night-action.png'),
  actionOneMore(mock: '06-night-action.png', viewer: Viewer.seer),
  actionTwoPicks(mock: '06-night-action.png', viewer: Viewer.seer),
  actionChosen(mock: '06-night-action.png', viewer: Viewer.seer),
  actionNotSent(mock: '06-night-action.png', viewer: Viewer.seer),
  actionTen(mock: '06-night-action.png'),
  actionTenLarge(mock: '06-night-action.png'),
  talk(mock: '08-talk.png', day: true),
  talkHeld(mock: '08-talk.png', day: true, viewer: Viewer.seer),
  talkSeer(mock: '08-talk.png', day: true, viewer: Viewer.seer),
  talkTroublemaker(mock: '08-talk.png', day: true, viewer: Viewer.troublemaker),
  talkDrunk(mock: '08-talk.png', day: true, viewer: Viewer.drunk),
  vote(mock: '09-vote.png', day: true),
  votePicked(mock: '09-vote.png', day: true),
  voteLocked(mock: '09-vote.png', day: true),
  count(mock: '10-the-count.png', day: true),
  results(mock: '11-results.png'),
  resultsGuest(mock: '11-results.png');

  const ComponentPage({
    this.mock,
    this.day = false,
    this.viewer = Viewer.villager,
    List<GroundKind>? grounds,
  }) : _grounds = grounds;

  /// The mock this page rebuilds, in docs/design/mocks/.
  final String? mock;
  final bool day;

  /// Ana's card: what her held faces say on this page.
  final Viewer viewer;
  final List<GroundKind>? _grounds;

  /// A page a player sees: held to the reading floor by the gallery.
  bool get playerScreen => mock != null;

  /// The grounds this page is drawn on: a screen on its own; a state page
  /// on each it is meant for.
  List<GroundKind> get grounds => playerScreen
      ? [if (day) GroundKind.day else GroundKind.night]
      : _grounds ?? GroundKind.values;

  /// What this phone has learned by this page in a first game: the hold on
  /// 04, "You" and the board's wave on 06, My night on 08.
  Set<Cue> get learned => switch (this) {
    card || cardHeld || cardHeldVillager || gates => const {},
    talk ||
    talkHeld ||
    talkSeer ||
    talkTroublemaker ||
    talkDrunk => {...Cue.values}..remove(Cue.holdMyNight),
    action ||
    actionHeld ||
    actionHeldVillager ||
    actionPicked ||
    actionOneMore ||
    actionTwoPicks ||
    actionChosen ||
    actionNotSent ||
    actionTen ||
    actionTenLarge => const {Cue.hold},
    _ => Cue.values.toSet(),
  };

  /// Puts the page in its state as a player would: a press, a hold, taps.
  Future<void> drive(WidgetTester tester) async {
    switch (this) {
      case buttons:
        await tester.startGesture(tester.getCenter(find.byKey(pressedKey)));
        await tester.pump(const Duration(milliseconds: 300));
      case cardHeld || cardHeldVillager:
        await holdDown(tester, find.byType(FaceDownCard));
      case actionHeld || actionHeldVillager:
        await holdDown(tester, _you);
      case talkHeld:
        await holdDown(tester, find.byType(PeekBox));
      case talkSeer || talkTroublemaker || talkDrunk:
        // The second hold shows My night's second page: the result.
        await holdAndLetGo(tester, find.byType(PeekBox));
        await holdDown(tester, find.byType(PeekBox));
      case actionPicked:
        await tester.tap(find.text(cleo.name));
      case actionOneMore:
        await tester.tap(find.text(NightCopy.left));
      case actionTwoPicks:
        await tester.tap(find.text(NightCopy.left));
        await tester.tap(find.text(NightCopy.right));
      case actionChosen:
        await tester.tap(find.text(NightCopy.left));
        await tester.tap(find.text(NightCopy.right));
        await tester.pump();
        await tester.tap(find.byType(PrimaryButton));
      case actionNotSent:
        await tester.tap(find.text(cleo.name));
        await tester.pump();
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(page.learned),
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
  await page.drive(tester);
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
    ComponentPage.cardHeldVillager => CardPage(viewer: page.viewer),
    ComponentPage.wait => const WaitPage(),
    ComponentPage.action ||
    ComponentPage.actionHeld ||
    ComponentPage.actionHeldVillager ||
    ComponentPage.actionPicked ||
    ComponentPage.actionOneMore ||
    ComponentPage.actionTwoPicks ||
    ComponentPage.actionChosen => BoardPage(viewer: page.viewer),
    ComponentPage.actionNotSent => BoardPage(viewer: page.viewer, fails: true),
    ComponentPage.actionTen => BoardPage(viewer: page.viewer, ten: true),
    ComponentPage.actionTenLarge => BoardPage(
      viewer: page.viewer,
      ten: true,
      textScale: 2,
    ),
    ComponentPage.talk ||
    ComponentPage.talkHeld ||
    ComponentPage.talkSeer ||
    ComponentPage.talkTroublemaker ||
    ComponentPage.talkDrunk => TalkPage(viewer: page.viewer),
    ComponentPage.vote ||
    ComponentPage.votePicked ||
    ComponentPage.voteLocked => const VotePage(),
    ComponentPage.count => const CountPage(),
    ComponentPage.results => const ResultsPage(),
    ComponentPage.resultsGuest => const ResultsPage(guest: true),
  };
}
