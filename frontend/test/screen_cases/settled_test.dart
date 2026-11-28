// Every state the screen sweep holds (sweptEntries(), from the catalogue) is
// held to the settled rules (test/helpers/settled_parts.dart): it opens with
// nothing already drawn pushed by what arrives later, and a finger down
// presses and moves only the part under it. At the owner's phone's size.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screen_sweep.dart';
import '../helpers/settled_parts.dart';
import 'settled_not_yet.dart';
import 'sweep_run.dart';

/// `--dart-define=SWEEP_ALL=true` prints every state's problems, one line
/// each, and fails none.
const _all = bool.fromEnvironment('SWEEP_ALL');

void main() {
  for (final entry in sweptEntries()) {
    final notYet = settledNotYet.keys.any(entry.id.startsWith);
    if (notYet && !_all) continue;
    testWidgets('${entry.id} opens in place and a touch moves only its '
        'part', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = sweepSizes[2];
      addTearDown(tester.view.reset);
      final opening = await openingProblems(tester, () async {
        await entry.build!(tester);
        for (var i = 0; i < (entry.frames ?? 10); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
      final problems = [...opening, ...await touchProblems(tester)];
      if (_all) {
        // ignore: avoid_print
        print('SETTLED ${entry.id} | ${problems.join(' || ')}');
        return;
      }
      expect(
        problems,
        isEmpty,
        reason:
            'frontend/test/screen_cases/settled_test.dart: ${entry.id}: '
            'something on the screen moved that nobody touched. Fix: keep '
            'the room of what arrives late from the first frame, and draw a '
            'touch on the part under the finger alone '
            '(test/helpers/settled_parts.dart).',
      );
    });
  }
}
