import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/band.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/panels.dart';
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
import '../live_game.dart';
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
  final LiveGame game;
  final String gameId;

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  LiveGameNotifier get _notifier =>
      ref.read(liveGameProvider(widget.gameId).notifier);

  @override
  Widget build(BuildContext context) {
    final me = widget.game.me;
    return StageSeconds(
      gameId: widget.gameId,
      deadline: me.deadline,
      builder: (context, seconds) {
        final left = StageShare.left(
          startedAt: me.stageStartedAt,
          deadline: me.deadline,
          secondsLeft: seconds,
        );
        return TalkView(
          me: me,
          secondsLeft: seconds,
          elapsed: left == null ? null : 1 - left,
          // A toggle; taps in a row go out in order, the latest last.
          onReady: () => unawaited(_notifier.setReady(!(me.ready ?? false))),
          onMyNightSeen: () => unawaited(_notifier.acknowledgeNightResults()),
          notSent: widget.game.unsent.contains(OutboxLane.ready),
          onTryAgain: () => unawaited(_notifier.retry(OutboxLane.ready)),
        );
      },
    );
  }
}

/// 08 Talk as drawn (first-time play spec, section 3 and section 7): the sun
/// over the rooftops, the talk's number loudest with "The village wakes"
/// beside it; My night, large, a hold box whose face is this phone's night
/// (the result first, window 1's page when it ran, then "Dealt"), with the
/// first-game hold ring on it; the deck tonight (a held portrait opens the
/// role's sheet); then how many are ready, as plain pips (this phone's own
/// tap counted at once), and "Ready to vote", outlined and never locked:
/// "Ready ✓" once tapped, tapped again to take it back. Nothing else to
/// read: the table talks (who is at it is the vote's list, 09).
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

  /// How far through the talk the sun is, 0 to 1; null when the server does
  /// not say when the talk started (the sun rests in one place).
  final double? elapsed;

  /// "Ready to vote" / "Ready ✓" tapped.
  final VoidCallback onReady;

  /// My night held for a reveal that counts.
  final VoidCallback? onMyNightSeen;

  /// The last ready tap got no answer: "Not sent." with [onTryAgain].
  final bool notSent;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final progress = me.progress;
    final ready = me.ready ?? false;
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: TimerBand.sun(
        secondsLeft: secondsLeft,
        elapsed: elapsed,
        title: TalkCopy.headline,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lg,
        children: [
          TeachingHold(
            target: TalkCopy.myNight,
            face: me.report.myNight,
            cue: Cue.holdMyNight,
            onRevealed: onMyNightSeen,
            cover: (teaching) => PeekBox(
              title: TalkCopy.myNight,
              teaching: teaching,
              large: true,
            ),
          ),
          _DeckStrip(deck: me.deck),
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

/// The deck tonight: each role once, as a small portrait with its name,
/// "3 Villagers" where there is more than one (the cold read on the real
/// screens: a row of tiny unnamed cards with number badges was not read as
/// the deck; a heading would put the talk over its word budget, and the
/// names say it). A tap or a hold opens the role's sheet (03b).
class _DeckStrip extends StatelessWidget {
  const _DeckStrip({required this.deck});

  final Map<RoleId, int> deck;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final MapEntry(key: role, value: count) in deck.entries)
        _DeckChip(
          role: role,
          label: count > 1
              ? TalkCopy.deckCount.fill({'n': count, 'roles': role.pluralName})
              : role.displayName,
          onOpen: () => unawaited(_openRole(context, role)),
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

/// One role of tonight's deck: its small portrait and its name, outlined.
class _DeckChip extends StatelessWidget {
  const _DeckChip({
    required this.role,
    required this.label,
    required this.onOpen,
  });

  final RoleId role;
  final String label;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        onLongPress: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Space.xxs,
            Space.xxs,
            Space.md,
            Space.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(skin.shape.radius),
            border: Border.all(color: ground.outline, width: skin.shape.ring),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: [
              RoleCard(role: role, size: RoleCardSize.thumbSmall),
              Flexible(
                child: FitWords(
                  label,
                  maxLines: 1,
                  style: skin.typography.action.copyWith(color: ground.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
