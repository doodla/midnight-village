// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
/// The screen states the sweep does not hold yet, each with the first thing
/// that fails, one line (found with `--dart-define=SWEEP_ALL=true`). Each is a
/// fault in the screen, found when the strict default came in: the rules were
/// not loosened for it. A to-do that only shrinks: fix a state, take it off.
/// A new state is never added here (screen_registry_test.dart).
const notYetSwept = <String, String>{
  '06-night-board-follow-up':
      'on a 360x640 phone the held face of the copied role is not whole on '
      'the screen: it runs 24 px past the bottom edge',
};
