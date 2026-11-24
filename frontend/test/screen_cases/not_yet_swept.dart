// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
/// The screen states the sweep does not hold yet, each with the first thing
/// that fails, one line (found with `--dart-define=SWEEP_ALL=true`). Each is a
/// fault in the screen, found when the strict default came in: the rules were
/// not loosened for it. A to-do that only shrinks: fix a state, take it off.
/// A new state is never added here (screen_registry_test.dart).
const notYetSwept = <String, String>{
  '06-night-board-follow-up':
      "the copied role's card lies over the players' cards and their names "
      'while it asks for a pick',
  // From main's rebuilt talk (08), which came in with the merge before the
  // rules had been run on it.
  '08-talk': _nightUp,
  '08-talk-open-drunk': _nightUp,
  '08-talk-held-insomniac-changed': _storyOver,
  '08-talk-held-tanner': _storyOver,
  '08-talk-held-doppelganger-werewolf': _storyOver,
  '08-talk-held-minion-none': _storyOver,
  '08-talk-held-doppelganger-troublemaker': _storyOver,
  '08-talk-held-doppelganger-insomniac': _storyOver,
  '08-talk-held-seer-timed-out': _storyOver,
  '08-talk-held-hunter': _storyOver,
  '08-talk-held-doppelganger-drunk': _storyOver,
  '08-talk-held-doppelganger-nothing': _storyOver,
  '08-talk-held-seer-centre': _storyOver,
  '08-talk-held-mason-alone': _storyOver,
  '08-talk-held-doppelganger-robber': _storyOver,
  '08-talk-held-doppelganger-villager': _storyOver,
};

const _nightUp =
    'My night, up by itself as the talk opens, lies over Ready: the first '
    'touch anywhere puts it away, so a finger on Ready only does that';

const _storyOver =
    "while My night is held, its story lies over Ready (a long night's story "
    'reaches the bottom of the board)';
