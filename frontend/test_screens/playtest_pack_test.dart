// The cold-read pack (first-time play spec, section 5, hook 10): four
// first-game journeys, each ONE phone of ONE recorded game (game 7,
// test/helpers/sheet/pack_journeys.dart), screen by screen, to
// build/playtest/<journey>/screen-NN.png. Every screen is that phone's own
// payload at a moment after the one before it, with time moving on the
// clocks; test/playtest/pack_journeys_test.dart holds the journeys to one
// game. 01 to 03b are the app's real screens through its routes and
// providers on the table's recorded lobby bodies (test_screens/
// table_fixtures.dart); the night and after are the screens' own views
// (the component sheet's pages, fed the step's payload). Each phone's taps
// are the ones the server recorded, and what it has learned carries from
// screen to screen. Hand a folder to someone who has never played and ask,
// screen by screen, what they would do next. Run it with
// `just playtest-pack`; it is not part of `just test`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/sheet/day_pages.dart';
import '../test/helpers/sheet/end_pages.dart';
import '../test/helpers/sheet/night_pages.dart';
import '../test/helpers/sheet/pack_journeys.dart';
import '../test/helpers/sheet/sheet_data.dart';
import 'screen_gallery.dart';
import 'table_fixtures.dart';

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// Game 7's phones by name.
const _viewers = {
  'Ana': Viewer.seer,
  'Ben': Viewer.robber,
  'Esme': Viewer.villager,
};

/// What a player learns by doing what a screen asks of them.
Set<Cue> _teaches(PackScreen screen) => switch (screen) {
  PackScreen.cardHeld => const {Cue.hold},
  PackScreen.boardHeld => const {Cue.hold},
  PackScreen.boardChosen => const {Cue.nightChoose},
  PackScreen.talkHeld => const {Cue.hold},
  PackScreen.voteLocked => const {Cue.voteLock},
  _ => const {},
};

/// "You" on the night board.
final _you = find.ancestor(
  of: find.text(NightCopy.you),
  matching: find.byType(FaceDownCard),
);

/// A view of the night or the day, on the phone's ground, with what it has
/// learned.
Future<void> _pumpView(
  WidgetTester tester,
  Widget view,
  Set<Cue> learned,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(learned),
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ref.watch(appThemeProvider),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: view,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// [step] of [journey] on its phone, driven to its state as a player would.
Future<void> _pump(
  WidgetTester tester,
  PackJourney journey,
  PackStep step,
  Set<Cue> learned,
) async {
  // A set-up journey's viewer plays no game here: never asked for.
  final viewer = _viewers[journey.viewer];
  final body = step.body;
  final lobby = step.sample?.replaceFirst('http/lobby/', '');
  Future<void> tapAll(Iterable<String> captions) async {
    for (final caption in captions) {
      await tester.tap(find.text(caption).last);
      await tester.pump();
    }
  }

  switch (step.screen) {
    case PackScreen.join:
      await pumpJoinAs(tester);
    case PackScreen.joinNamed:
      await pumpJoinAs(tester, name: journey.viewer);
    case PackScreen.joinLink:
      await pumpJoinLinkTo(tester, _code);
    case PackScreen.joinLinkNamed:
      await pumpJoinLinkTo(tester, _code, name: journey.viewer);
    case PackScreen.table:
      await pumpTableOf(tester, lobby!, journey.viewer);
    case PackScreen.deck:
      await pumpDeckOf(tester, lobby!, journey.viewer);
    case PackScreen.deckEdit:
      await pumpDeckOf(tester, lobby!, journey.viewer);
    case PackScreen.deckRole:
      await pumpDeckOf(tester, lobby!, journey.viewer, role: true);
    case PackScreen.card || PackScreen.cardHeld:
      await _pumpView(tester, CardPage(viewer: viewer!, look: body), learned);
      if (step.screen == PackScreen.cardHeld) {
        await holdDown(tester, find.byType(FaceDownCard));
      }
    case PackScreen.board ||
        PackScreen.boardHeld ||
        PackScreen.boardPicked ||
        PackScreen.boardChosen:
      await _pumpView(
        tester,
        BoardPage(
          viewer: viewer!,
          table: (_) => body!,
          secondsLeft: step.secondsLeft!,
        ),
        learned,
      );
      // The opening wave, done.
      await tester.pump(const Duration(seconds: 2));
      switch (step.screen) {
        case PackScreen.boardHeld:
          await holdDown(tester, _you);
        case PackScreen.boardPicked:
          await tapAll(journey.taps);
        case PackScreen.boardChosen:
          await tapAll(journey.taps);
          await tester.tap(find.byType(PrimaryButton));
          await tester.pump();
        default:
      }
    case PackScreen.talkOpen || PackScreen.talk || PackScreen.talkHeld:
      await _pumpView(
        tester,
        TalkPage(
          viewer: viewer!,
          me: body,
          secondsLeft: step.secondsLeft!,
          elapsed: step.share,
          open: step.screen == PackScreen.talkOpen,
        ),
        learned,
      );
      if (step.screen == PackScreen.talkHeld) {
        await holdDown(tester, find.byType(PeekBox));
      }
    case PackScreen.vote || PackScreen.votePicked || PackScreen.voteLocked:
      await _pumpView(
        tester,
        VotePage(
          me: body,
          secondsLeft: step.secondsLeft!,
          remaining: 1 - step.share!,
        ),
        learned,
      );
      // A recorded pick or lock is the payload's own; else the phone taps.
      if (body!['my_vote'] == null && step.screen != PackScreen.vote) {
        await tester.tap(find.text(journey.vote));
        await tester.pump();
        if (step.screen == PackScreen.voteLocked) {
          await tester.tap(find.byType(PrimaryButton));
          await tester.pump();
        }
      }
    case PackScreen.count:
      await _pumpView(
        tester,
        CountPage(
          game: EndGame.five,
          viewerId: viewerIn(body!, journey.viewer),
        ),
        learned,
      );
    case PackScreen.results || PackScreen.resultsEnd:
      await _pumpView(
        tester,
        ResultsPage(
          viewer: viewer!,
          game: EndGame.five,
          guest: !journey.host,
          viewerId: viewerIn(body!, journey.viewer),
        ),
        learned,
      );
      if (step.screen == PackScreen.resultsEnd) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
      }
  }
  await tester.pump();
}

/// Game 7's table code, from its recorded lobby.
final _code =
    PackStep(PackScreen.table, 'http/lobby/settings_deck_chip').body!['code']
        as String;

void main() {
  for (final MapEntry(key: name, value: journey) in packJourneys.entries) {
    group(name, () {
      final dir = Directory('build/playtest/$name');
      setUpAll(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
      });

      // A first game: nothing learned at the start, then what each screen
      // taught, carried on.
      final learned = <Cue>{};
      for (final (i, step) in journey.steps.indexed) {
        final file = 'screen-${(i + 1).toString().padLeft(2, '0')}';
        testWidgets('$file ${step.screen.name}', (tester) async {
          final before = {...learned};
          learned.addAll(_teaches(step.screen));
          final capture = await captureScreen(
            tester,
            (tester) => _pump(tester, journey, step, before),
            width: _width,
            playerScreen: true,
          );
          if (capture.failure case final failure?) fail(failure);
          File('${dir.path}/$file.png').writeAsBytesSync(capture.png!);
          expect(capture.findings, isEmpty);
        });
      }
    });
  }
}
