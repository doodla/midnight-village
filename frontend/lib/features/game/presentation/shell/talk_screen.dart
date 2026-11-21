import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/faces/face_content.dart';
import '../../../../design_system/faces/held_face.dart';
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
import '../../../../design_system/teach/teaching_hold.dart';
import '../../domain/game_me.dart';
import '../live_game.dart';
import '../stage_seconds.dart';

/// 08 Talk, wired to the server: [TalkView] fed from `/me/` (with this
/// phone's taps on it), the sun and its number from the stage's deadline
/// ([StageSeconds]), "Ready to vote" sent through the game's outbox as a
/// toggle. A phone whose night told it something it has not acknowledged
/// opens the talk with My night open, once ([TalkView.resultOpen]): the ack
/// goes when it is shown, a tap puts it away. Otherwise the results are
/// acknowledged the first time My night is held for a reveal that counts.
/// The talk ends on the server (everyone ready, or its deadline); this
/// screen never decides it.
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

  /// My night is open: decided once, on the talk's first frame (results the
  /// server has not had acknowledged, and a night that told something);
  /// false once put away. A restart after the ack opens nothing.
  late bool _open =
      widget.game.me.hasUnseenResults && widget.game.me.report.tellsSomething;

  @override
  void initState() {
    super.initState();
    // Shown is seen: the ack goes once the first frame is up; nothing
    // waits on it.
    if (_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_notifier.acknowledgeNightResults());
      });
    }
  }

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
          resultOpen: _open,
          onPutAway: () => setState(() => _open = false),
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
/// first-game hold ring on it; or, with [resultOpen], that face itself, open
/// on the paper card a hold shows, until a tap puts it away into the box;
/// the deck tonight (a held portrait opens the role's sheet); then how many
/// are ready, as plain pips (this phone's own tap counted at once), and
/// "Ready to vote", outlined and never locked, open card or not: "Ready ✓"
/// once tapped, tapped again to take it back. Nothing else to read: the
/// table talks (who is at it is the vote's list, 09).
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
    this.resultOpen = false,
    this.onPutAway,
    this.notSent = false,
    this.onTryAgain,
  });

  /// The least room the body is given under the band: My night and a row
  /// of the deck, or the open card's words and a portrait. A shorter phone
  /// (large text) scrolls the band and the body together.
  static final minBody = PeekBox.largeCardSize.height * 1.5;

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

  /// My night is shown open, no hold: the talk's first sight of a night
  /// that told this phone something. [onPutAway] is the tap that closes it.
  final bool resultOpen;
  final VoidCallback? onPutAway;

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
      // The body is given the room under the band. Open, the card takes it
      // (its portrait gives up what the words need); else My night, and the
      // deck in what is left (_DeckGrid): every word on screen.
      fitsHeight: true,
      minBodyHeight: TalkView.minBody,
      body: resultOpen
          ? _OpenNight(face: me.report.myNight, onPutAway: onPutAway)
          : LayoutBuilder(
              builder: (context, box) {
                // The large box where the deck still fits under it whole,
                // portraits and all; else the mock's smaller box where that
                // keeps the portraits; else whichever leaves the deck whole.
                double above(bool large) =>
                    PeekBox.heightFor(
                      context,
                      large: large,
                      teaching: true,
                      title: TalkCopy.myNight,
                    ) +
                    Space.lg;
                bool fits(bool large, {required bool portraits}) =>
                    _DeckGrid.fits(
                      context,
                      me.deck,
                      box.biggest,
                      above: above(large),
                      portraits: portraits,
                    );
                final large =
                    fits(true, portraits: true) ||
                    (!fits(false, portraits: true) &&
                        fits(true, portraits: false));
                return CustomMultiChildLayout(
                  delegate: _BoxThenDeck(),
                  children: [
                    LayoutId(
                      id: _BoxThenDeck.box,
                      child: TeachingHold(
                        target: TalkCopy.myNight,
                        face: me.report.myNight,
                        onRevealed: onMyNightSeen,
                        cover: (teaching) => PeekBox(
                          title: TalkCopy.myNight,
                          teaching: teaching,
                          large: large,
                        ),
                      ),
                    ),
                    LayoutId(
                      id: _BoxThenDeck.deck,
                      child: _DeckGrid(deck: me.deck),
                    ),
                  ],
                );
              },
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
            label: CommonCopy.progress.fill({
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

/// My night open on the talk's first frame: the paper card a hold shows,
/// lying on the table, as tall as its words and portrait need and the room
/// under the band allows; a tap anywhere on it puts it away into the box
/// (the deck comes back under it).
/// Spoken as the box is ("My night"), never its words: a phone on the table
/// does not read a secret aloud.
class _OpenNight extends StatelessWidget {
  const _OpenNight({required this.face, this.onPutAway});

  final FaceContent face;
  final VoidCallback? onPutAway;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: TalkCopy.myNight,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPutAway,
      child: Align(
        alignment: Alignment.topCenter,
        child: HeldFace(content: face, page: 0),
      ),
    ),
  );
}

/// My night at the top, its own height; the deck in the rest of the body's
/// height (never a Flex overflow: on a screen too short even for the box,
/// the deck gets no room and the box runs on under the actions).
class _BoxThenDeck extends MultiChildLayoutDelegate {
  _BoxThenDeck();

  static const box = 'box';
  static const deck = 'deck';

  @override
  void performLayout(Size size) {
    final top = layoutChild(
      box,
      BoxConstraints(minWidth: size.width, maxWidth: size.width),
    );
    positionChild(box, Offset.zero);
    final y = top.height + Space.lg;
    layoutChild(
      deck,
      BoxConstraints.tightFor(
        width: size.width,
        height: math.max(0.0, size.height - y),
      ),
    );
    positionChild(deck, Offset(0, y));
  }

  @override
  bool shouldRelayout(_BoxThenDeck oldDelegate) => false;
}

/// The deck tonight: each role once, as a small portrait with its name,
/// "3 Villagers" where there is more than one (the cold read on the real
/// screens: a row of tiny unnamed cards with number badges was not read as
/// the deck; a heading would put the talk over its word budget, and the
/// names say it). A tap or a hold opens the role's sheet (03b).
///
/// In columns, sized to the room it is given: two columns at the acting
/// size, then at the caption size, then three; then the names alone (no
/// portrait), in two columns at the acting size, the caption size, then
/// three. The first that holds every chip whole in the height is used
/// (playtest: chips that ran under the fade at 320 wide read as not in
/// play). Only where none fits (a short phone with large text) does it
/// scroll, fading at the foot.
class _DeckGrid extends StatelessWidget {
  const _DeckGrid({required this.deck});

  final Map<RoleId, int> deck;

  /// The chip's paper around its portrait and name ([_DeckChip]), and
  /// around a name alone.
  static const _pad = EdgeInsets.fromLTRB(
    Space.xxs,
    Space.xxs,
    Space.md,
    Space.xxs,
  );
  static const _namePad = EdgeInsets.symmetric(
    horizontal: Space.sm,
    vertical: Space.xxs,
  );

  List<(RoleId, String)> get _chips => [
    for (final MapEntry(key: role, value: count) in deck.entries)
      (
        role,
        count > 1
            ? TalkCopy.deckCount.fill({'n': count, 'roles': role.pluralName})
            : role.displayName,
      ),
  ];

  /// The first layout, roomiest first, whose chips are whole and whose rows
  /// fit [room]: (columns, type, with portraits, gap).
  static (int, TextStyle, bool, double)? _layout(
    BuildContext context,
    List<(RoleId, String)> chips,
    Size room, {
    bool portraits = false,
  }) {
    final skin = context.skin;
    final type = skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final thumb = RoleCardSize.thumbSmall.thumbnail!;
    final edge = 2 * skin.shape.ring;
    double measure(String text, TextStyle style, {bool height = false}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final value = height ? painter.height : painter.width;
      painter.dispose();
      return value;
    }

    for (final (columns, style, portrait, gap) in [
      (2, type.action, true, Space.sm),
      (2, type.badge, true, Space.sm),
      (3, type.badge, true, Space.sm),
      if (!portraits) ...[
        (2, type.action, false, Space.xs),
        (2, type.badge, false, Space.xs),
        (3, type.badge, false, Space.xs),
      ],
    ]) {
      final cell = (room.width - (columns - 1) * gap) / columns;
      final around = portrait
          ? _pad.horizontal + thumb.width + Space.sm
          : _namePad.horizontal;
      final whole = chips.every(
        (c) => edge + around + measure(c.$2, style) <= cell,
      );
      final line = measure('Ag', style, height: true);
      final row = portrait
          ? edge + _pad.vertical + math.max(thumb.height, line)
          : edge + _namePad.vertical + line;
      final rows = (chips.length / columns).ceil();
      if (whole && rows * row + (rows - 1) * gap <= room.height) {
        return (columns, style, portrait, gap);
      }
    }
    return null;
  }

  /// [deck]'s chips fit whole in [room] below [above] ([portraits]: with
  /// their portraits).
  static bool fits(
    BuildContext context,
    Map<RoleId, int> deck,
    Size room, {
    required double above,
    bool portraits = false,
  }) =>
      _layout(
        context,
        _DeckGrid(deck: deck)._chips,
        Size(room.width, math.max(0.0, room.height - above)),
        portraits: portraits,
      ) !=
      null;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final chips = _chips;
      if (_layout(context, chips, box.biggest) case (
        final columns,
        final style,
        final portrait,
        final gap,
      )) {
        final cell = (box.maxWidth - (columns - 1) * gap) / columns;
        return _grid(context, chips, cell, style, portrait, gap);
      }
      final cell = (box.maxWidth - Space.xs) / 2;
      return FadingScroll(
        child: _grid(
          context,
          chips,
          cell,
          context.skin.typography.badge,
          false,
          Space.xs,
        ),
      );
    },
  );

  Widget _grid(
    BuildContext context,
    List<(RoleId, String)> chips,
    double cell,
    TextStyle style,
    bool portrait,
    double gap,
  ) => Wrap(
    spacing: gap,
    runSpacing: gap,
    children: [
      for (final (role, label) in chips)
        SizedBox(
          width: cell,
          child: _DeckChip(
            role: role,
            label: label,
            style: style,
            portrait: portrait,
            onOpen: () => unawaited(_openRole(context, role)),
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

/// One role of tonight's deck: its small portrait (unless [portrait] is
/// false: a short phone) and its name, outlined.
class _DeckChip extends StatelessWidget {
  const _DeckChip({
    required this.role,
    required this.label,
    required this.style,
    required this.portrait,
    required this.onOpen,
  });

  final RoleId role;
  final String label;
  final TextStyle style;
  final bool portrait;
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
          padding: portrait ? _DeckGrid._pad : _DeckGrid._namePad,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(skin.shape.radius),
            border: Border.all(color: ground.outline, width: skin.shape.ring),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: [
              if (portrait) RoleCard(role: role, size: RoleCardSize.thumbSmall),
              Flexible(
                child: FitWords(
                  label,
                  maxLines: 1,
                  style: style.copyWith(color: ground.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
