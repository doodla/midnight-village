import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/primitives/band.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/panels.dart';
import '../../../../design_system/primitives/player_token.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/progress_pips.dart';
import '../../../../design_system/primitives/role_card.dart';
import '../../../../design_system/primitives/role_sheet_body.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sheet_scaffold.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../../design_system/teach/learned_store.dart';
import '../../../../design_system/teach/teaching_hold.dart';
import '../../domain/game_me.dart';
import '../protocol_two_game.dart';
import '../stage_seconds.dart';

/// 08 Talk, wired to the server: [TalkView] fed from `/me/` (with this
/// phone's taps on it), the sun and its number from the stage's deadline
/// ([StageSeconds]), "Ready to vote" sent through the game's outbox as a
/// toggle, and the results acknowledged the first time My night is held for
/// a reveal that counts. The talk ends on the server (everyone ready, or its
/// deadline); this screen never decides it.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key, required this.game, required this.gameId});

  /// The game as the shell has it (`/me/` with this phone's taps on it).
  final ProtocolTwoGame game;
  final String gameId;

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  final _share = StageShare();

  ProtocolTwoGameNotifier get _notifier =>
      ref.read(protocolTwoGameProvider(widget.gameId).notifier);

  @override
  Widget build(BuildContext context) {
    final me = widget.game.me;
    return StageSeconds(
      gameId: widget.gameId,
      deadline: me.deadline,
      builder: (context, seconds) => TalkView(
        me: me,
        secondsLeft: seconds,
        elapsed: 1 - _share.left(me.stage, seconds),
        // A toggle; taps in a row go out in order, the latest last.
        onReady: () => unawaited(_notifier.setReady(!(me.ready ?? false))),
        onMyNightSeen: () => unawaited(_notifier.acknowledgeNightResults()),
        notSent: widget.game.unsent.contains(OutboxLane.ready),
        onTryAgain: () => unawaited(_notifier.retry(OutboxLane.ready)),
      ),
    );
  }
}

/// 08 Talk as drawn (first-time play spec, section 3 and section 7): the sun
/// over the rooftops and the talk's number, loudest; "The village wakes";
/// My night, a hold box whose face is this phone's night (the result
/// first, window 1's page when it ran, then "Dealt"), with the first-game
/// hold ring on it; the deck tonight (a held portrait opens the role's
/// sheet); everyone at the table in seat order, token and whole name; then how
/// many are ready, as plain pips, and "Ready to vote", outlined and never
/// locked: "Ready ✓" once tapped, tapped again to take it back. Nothing else
/// to read: the table talks.
///
/// It takes plain data and callbacks: [me] is `/me/` with this phone's taps
/// on it (its own [GameMe.ready]).
class TalkView extends StatelessWidget {
  const TalkView({
    super.key,
    required this.me,
    required this.secondsLeft,
    required this.elapsed,
    required this.onReady,
    this.onMyNightSeen,
    this.notSent = false,
    this.onTryAgain,
  });

  final GameMe me;

  /// Null: the talk has no deadline (no number).
  final int? secondsLeft;

  /// How far through the talk the sun is, 0 to 1.
  final double elapsed;

  /// "Ready to vote" / "Ready ✓" tapped.
  final VoidCallback onReady;

  /// My night held for a reveal that counts.
  final VoidCallback? onMyNightSeen;

  /// The last ready tap got no answer: "Not sent." with [onTryAgain].
  final bool notSent;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final progress = me.progress;
    final ready = me.ready ?? false;
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: TimerBand.sun(secondsLeft: secondsLeft, elapsed: elapsed),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lg,
        children: [
          Semantics(
            header: true,
            child: FitWords(
              TalkCopy.headline,
              style: skin.typography.screenTitle,
            ),
          ),
          TeachingHold(
            target: TalkCopy.myNight,
            face: me.report.myNight,
            cue: Cue.holdMyNight,
            onRevealed: onMyNightSeen,
            cover: (teaching) =>
                PeekBox(title: TalkCopy.myNight, teaching: teaching),
          ),
          _DeckStrip(deck: me.deck),
          TableNames(seats: me.seats),
        ],
      ),
      actions: [
        if (notSent && onTryAgain != null)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: onTryAgain,
          ),
        if (progress != null)
          ProgressPips(
            done: progress.done,
            total: progress.needed,
            label: TalkCopy.progress.fill({
              'd': progress.done,
              'n': progress.needed,
            }),
          ),
        // Never amber, never locked: the talk must not shout "end it".
        PrimaryButton.quiet(
          label: ready ? CommonCopy.readyDone : TalkCopy.readyToVote,
          onPressed: onReady,
        ),
      ],
    );
  }
}

/// Everyone at the table in seat order: each player's token and whole name
/// (wrapped between words where it must, never cut), so the table can name
/// each other while it talks. Nothing about anyone's progress.
class TableNames extends StatelessWidget {
  const TableNames({super.key, required this.seats});

  final List<NightSeat> seats;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final style = skin.typography.nameSmall.copyWith(
      color: context.ground.text,
    );
    return Wrap(
      spacing: Space.lg,
      runSpacing: Space.sm,
      children: [
        for (final seat in seats)
          Semantics(
            label: seat.name,
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.sm,
              children: [
                PlayerToken(seat.token, size: TokenSize.card),
                Flexible(child: FitWords(seat.name, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The deck tonight: each role once, its count where it is more than one;
/// a held portrait opens the role's sheet (03b).
class _DeckStrip extends StatelessWidget {
  const _DeckStrip({required this.deck});

  final Map<RoleId, int> deck;

  @override
  Widget build(BuildContext context) => Row(
    spacing: Space.smPlus,
    children: [
      for (final MapEntry(key: role, value: count) in deck.entries)
        Flexible(
          child: RoleCard(
            role: role,
            size: RoleCardSize.mini,
            count: count,
            onLongPress: () => unawaited(_openRole(context, role)),
          ),
        ),
    ],
  );

  static Future<void> _openRole(BuildContext context, RoleId role) =>
      showSkinSheet<void>(
        context,
        builder: (sheet) => SheetScaffold(
          actions: [
            const Spacer(),
            PrimaryButton(
              label: RoleSheetCopy.close,
              onPressed: () => Navigator.of(sheet).pop(),
              size: ButtonSize.compact,
            ),
          ],
          child: RoleSheetBody(role),
        ),
      );
}
