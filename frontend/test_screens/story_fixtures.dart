import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';

import '../test/helpers/component_sheet.dart' show learnedOverrides;
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/sheet/story_samples.dart';
import 'shell_fixtures.dart';

/// 08 with My night up on the phone of [night] (story_samples.dart): a
/// recorded night through the shell, held; a night no game recorded (edited
/// off the contract, which the shell's checked server would refuse) as the
/// talk's view alone, its night up as the talk opens.
Future<void> pumpTalkStory(WidgetTester tester, String night) async {
  final me = allNights[night]!();
  if (recordedNights.containsKey(night)) {
    return pumpTalkHeldNight(tester, me);
  }
  await pumpSkinned(
    tester,
    ProviderScope(
      overrides: learnedOverrides({...Cue.values}),
      child: TalkView(
        me: GameMe.fromJson(me),
        secondsLeft: 192,
        onReady: () {},
        openNight: true,
      ),
    ),
  );
  await tester.pump();
}
