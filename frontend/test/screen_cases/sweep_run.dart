// The screen sweep over the gallery's catalogue: every screen state that
// `just screens` draws (test_screens/screen_catalogue.dart) is pumped once and
// held to the sweep's rules (test/helpers/screen_sweep.dart) at three phones
// and three text sizes, its main action pressed by a finger. A state is
// declared once, in the catalogue; this file derives its test from it. The
// states that do not hold yet are listed in not_yet_swept.dart, each with what
// fails, and are not run here: that list is a to-do that only shrinks
// (screen_registry_test.dart).
//
// Each state is also watched at rest (still_screen.dart): it asks for no
// frames but its clock's, its field's cursor and its ambient motion, and a
// clock tick redraws the clock alone.
//
// The catalogue is swept in [sweepShards] parts, one test file each
// (`sweep_1of4_test.dart` ...), so `flutter test` runs them side by side.
import 'package:flutter_test/flutter_test.dart';

import '../../test_screens/screen_catalogue.dart';
import '../helpers/screen_sweep.dart';
import '../helpers/stage_clock.dart';
import '../helpers/still_screen.dart';
import 'not_yet_swept.dart';

/// How many parts the sweep runs in.
const sweepShards = 4;

/// `--dart-define=SWEEP_ALL=true` sweeps the states in the to-do list too,
/// and prints what fails, one line each, for the list.
const _all = bool.fromEnvironment('SWEEP_ALL');

/// The catalogue's states the sweep holds: every screen built, but the
/// component sheet's pages (fit_sweep_test.dart sweeps those, every page at
/// every width and text size) and a page that is a state drawn at a larger
/// text size (the sweep turns its twin through every text size).
List<ScreenEntry> sweptEntries() => [
  for (final entry in screenCatalogue)
    if (entry.build != null &&
        !entry.id.startsWith('c-') &&
        entry.textScale == 1)
      entry,
];

/// The `main` of part [shard] (1 to [sweepShards]).
void runSweep(int shard) {
  final entries = sweptEntries();
  for (var i = shard - 1; i < entries.length; i += sweepShards) {
    final entry = entries[i];
    final notYet = notYetSwept[entry.id];
    if (notYet != null && !_all) continue;
    testWidgets(entry.id, (tester) async {
      final plan = entry.sweep;
      final problems = await sweepScreen(
        tester,
        entry.build!,
        // Every state: a stage the server times shows its clock
        // (stage_clock.dart).
        SweepPlan(
          main: plan.main,
          mustSee: plan.mustSee,
          apart: plan.apart,
          rules: [...plan.rules, stageClockProblems],
          whenOpened: plan.whenOpened,
        ),
        settleFrames: entry.frames ?? 10,
      );
      if (_all) {
        // ignore: avoid_print
        print(
          'SWEPT ${entry.id} | ${problems.isEmpty ? 'ok' : problems.join(' || ')}',
        );
        return;
      }
      expect(
        problems,
        isEmpty,
        reason:
            '${entry.id} breaks the screen rules above. Fix the screen; a '
            'state that cannot be fixed in this change is not hidden by '
            'loosening a rule for everything.',
      );
    });
    if (restNotYet.containsKey(entry.id) && !_all) continue;
    testWidgets('${entry.id} at rest', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = sweepSizes.last;
      addTearDown(tester.view.reset);
      await entry.build!(tester);
      for (var i = 0; i < (entry.frames ?? 10); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final rest = await watchAtRest(tester);
      final problems = [...rest.problems, ...await clockTickProblems(tester)];
      if (_all) {
        // ignore: avoid_print
        print(
          'REST ${entry.id} | ${rest.frames} frames | '
          '${problems.isEmpty ? 'ok' : problems.join(' || ')}',
        );
        return;
      }
      expect(
        problems,
        isEmpty,
        reason:
            '${entry.id} keeps drawing while nothing happens, or its clock '
            'redraws more than itself (test/helpers/still_screen.dart). Make '
            'the source still, or move it into a source on the allowed list.',
      );
    });
  }
}
