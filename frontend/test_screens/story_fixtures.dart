import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/sheet/story_samples.dart';
import 'shell_fixtures.dart';

/// 08 with My night up on the phone of [night] (story_samples.dart): a
/// recorded night through the shell, held.
Future<void> pumpTalkStory(WidgetTester tester, String night) =>
    pumpTalkHeldNight(tester, allNights[night]!());
