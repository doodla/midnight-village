import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';

import '../../helpers/component_sheet.dart';

// The sheet's screen pages reach the state they are named for, driven the way
// a player would: a page that silently shows an earlier state would let the
// contrast, fit and amber tests (and the cold-read pack) judge the wrong
// picture.

void main() {
  final shows = <ComponentPage, List<String>>{
    ComponentPage.actionPicked: ['Choose Cleo'],
    ComponentPage.actionOneMore: [NightCopy.chooseMore],
    ComponentPage.actionTwoPicks: ['Choose Left, Right'],
    ComponentPage.actionChosen: [NightCopy.chosen],
    ComponentPage.actionNotSent: [BannerCopy.notSent, BannerCopy.tryAgain],
    ComponentPage.talkSeer: ["Cleo's card: Werewolf."],
    ComponentPage.talkTroublemaker: ['You swapped Ben and Dev.'],
    ComponentPage.talkDrunk: ['Right is yours. Unseen.'],
    ComponentPage.voteLocked: [VoteCopy.locked],
  };
  for (final MapEntry(key: page, value: words) in shows.entries) {
    testWidgets('${page.name} shows ${words.join(', ')}', (tester) async {
      await pumpComponentPage(tester, page, page.grounds.single);
      for (final word in words) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
    });
  }

  testWidgets('held pages show a face', (tester) async {
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
