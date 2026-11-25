import '../../../design_system/primitives/countdown.dart';
import 'live_game.dart';

export '../../../design_system/primitives/countdown.dart'
    show Countdown, StageShare;

/// The countdown of a stage that ends at [deadline], by the server's clock
/// ([LiveGameNotifier.untilServer]), for the stage's clock to count: a screen
/// hands it down and never reads the seconds (`Countdown`, `ClockTick`). It
/// counts down to 0 and stays there: the server says when the stage ends
/// (the game fetches `/me/` after the deadline), never this. [startedAt] (the
/// server's `stage_started_at`) gives the clock its share of the stage. Null
/// [deadline] (an untimed stage): null, no number.
Countdown? stageCountdown(
  LiveGameNotifier notifier, {
  required DateTime? deadline,
  DateTime? startedAt,
}) => deadline == null
    ? null
    : Countdown.to(deadline, until: notifier.untilServer, startedAt: startedAt);
