import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';

import '../../helpers/component_sheet.dart';

// The sheet's screen pages reach the state they are named for, driven the way
// a player would: a page that silently shows an earlier state would let the
// contrast, fit and amber tests (and the cold-read pack) judge the wrong
// picture.

/// A phone, as the gallery draws it.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final shows = <ComponentPage, List<String>>{
    ComponentPage.actionPicked: ['See Cleo'],
    ComponentPage.actionOneMore: [NightCopy.chooseMore],
    ComponentPage.actionTwoPicks: ['See Left, Right'],
    ComponentPage.actionChosen: [NightCopy.chosen],
    ComponentPage.actionNotSent: [BannerCopy.notSent, BannerCopy.tryAgain],
    ComponentPage.talkHeld: ["Cleo's card was: Werewolf."],
    ComponentPage.talkRobber: ["You took Ana's card: Seer."],
    ComponentPage.talkLoneWerewolf: ['Only you.', 'Left was: Werewolf.'],
    ComponentPage.talkDrunk: ['You took Middle, unseen.'],
    ComponentPage.talkDoppelganger: [
      'You copied Ben.',
      'Left was: Villager. Middle was: Villager.',
    ],
    ComponentPage.actionFollowUpHeld: ['You copied Ben.', NightCopy.seer],
    ComponentPage.voteLocked: [VoteCopy.locked],
  };
  for (final MapEntry(key: page, value: words) in shows.entries) {
    testWidgets('${page.name} shows ${words.join(', ')}', (tester) async {
      _phone(tester);
      await pumpComponentPage(tester, page, page.grounds.single);
      for (final word in words) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
    });
  }

  testWidgets('held pages show a face', (tester) async {
    _phone(tester);
    for (final page in [
      ComponentPage.cardHeld,
      ComponentPage.actionHeld,
      ComponentPage.talkHeld,
    ]) {
      await pumpComponentPage(tester, page, page.grounds.single);
      expect(find.byType(HeldFace), findsOneWidget, reason: page.name);
    }
  });
}
