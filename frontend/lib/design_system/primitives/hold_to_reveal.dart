import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../faces/face_content.dart';
import '../faces/held_face.dart';
import '../layout/space.dart';
import '../skin/ground_scope.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import 'finger_hold.dart';
import 'paper_flip.dart';
import 'paper_light.dart';

/// How the face came to be shown.
enum _Shown { held, activated }

/// Whether the [HoldToReveal] round this cover is being held now: the
/// hold cue's ring fills while it is ([HoldCue]).
class HoldPress extends InheritedWidget {
  const HoldPress({super.key, required this.held, required super.child});

  final bool held;

  /// False outside a [HoldToReveal].
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HoldPress>()?.held ?? false;

  @override
  bool updateShouldNotify(HoldPress old) => old.held != held;
}

/// A secret behind press-and-hold (first-time play spec, section 2): [cover]
/// shows until the player presses; [face] is drawn as a role card
/// ([HeldFace]). [inPlace] (04, the card in your hand): the card turns over
/// where it is, filling the cover's own frame, like a piece of paper
/// ([PaperFlip]: a cut with reduce motion; product owner: a friendly game,
/// the card flips under the thumb), with a light vibration as the face
/// lands. Otherwise the face is drawn above the touch point,
/// as large as fits there (below it, clear of the thumb, when above has
/// less room).
///
/// - The face shows [holdDelay] after the press and hides on release, however
///   long it is held (no cap: spec section 8).
/// - [onRevealed] fires once the face has been visible [revealedAfter]: a
///   reveal counts then (it learns the `hold` cue and opens gates). Both are
///   timed from the finger, by the pointer events' own times
///   ([FingerTimedLongPress], [fingerTime]): a busy phone that handles the
///   landing late still counts a hold of [holdDelay] plus [revealedAfter]
///   as the finger lifts.
/// - A tap is not a reveal: it reaches the [cover] at once (on the night
///   board, a pick), with no double-tap wait.
/// - A screen reader's activate, a switch or the keyboard (Enter, Space)
///   shows it until activated again, reads it aloud, and counts as a reveal
///   at once. Until then the face is a button labelled "{target}, hidden.
///   Activate to show."
/// - Each new showing shows the face's next page.
///
/// A face shown in any way still hides by itself when focus moves away from
/// it, when another route covers its screen (a dialog's scrim never has the
/// secret faintly behind it), and when the app leaves the foreground.
///
/// Nothing about the hidden state depends on the secret: the face is built
/// only while shown (it is not in the tree, or read out, otherwise), and the
/// widget is always the cover's size, the face drawn in the cover's box or
/// above it in the overlay. Its art is precached
/// (`precacheArt`), so revealing it takes the same time whatever it is and
/// fetches nothing.
class HoldToReveal extends StatefulWidget {
  const HoldToReveal({
    super.key,
    required this.cover,
    required this.face,
    required this.target,
    this.onRevealed,
    this.onRevealChanged,
    this.inPlace = false,
    this.away = false,
  });

  final Widget cover;

  /// The face is drawn by the screen, somewhere of its own (08's square: the
  /// board's area, from its top), while [onRevealChanged] says it is shown;
  /// this draws nothing but the [cover]. Every other rule here holds.
  final bool away;

  /// The face replaces the cover in its own box instead of being drawn over
  /// the screen.
  final bool inPlace;
  final FaceContent face;

  /// What this is ("Your card", "You", "My night"): its spoken name.
  final String target;

  /// Told each time a reveal counts.
  final VoidCallback? onRevealed;

  /// Told each time the face is shown (true) or hidden (false).
  final ValueChanged<bool>? onRevealChanged;

  /// How long a press lasts before the face shows: a shorter one is a tap
  /// (on the night board, a pick).
  static const holdDelay = Duration(milliseconds: 120);

  /// How long a face must be visible for the reveal to count.
  static const revealedAfter = Duration(milliseconds: 800);

  /// Between the face's lower edge and the touch point.
  static const gap = Space.lg;

  /// Below the touch point, room for the thumb, when there is no room above.
  static const thumb = 72.0;

  /// The face turning over in place, to the face ([PaperFlip.turn]) and
  /// back to the cover ([PaperFlip.turnBack], never slower than `press`).
  static const flip = PaperFlip.turn;

  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal>
    with WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  _Shown? _shown;

  /// Where the face is drawn above: the touch point as a share of the
  /// cover's own box (its centre for a face shown with no touch). The face
  /// follows the card, so a screen that changes under a held finger (a
  /// browser's bar, a turned phone, the text size) never strands it.
  var _anchor = const Offset(0.5, 0.5);

  /// How many times the face has been shown: which page is next.
  var _showings = 0;
  var _focusHighlight = false;

  /// A finger is on the card (before it is a hold): the card dips.
  var _touching = false;
  Timer? _counts;

  /// When the finger on the card landed and lifted, by the events' own
  /// times ([fingerTime]): a hold that lasted long enough counts on the
  /// lift even when the app was too busy to run its timers meanwhile.
  Duration? _landed;
  Duration? _lifted;

  bool get _visible => _shown != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Another route over this one (a dialog, a sheet, the next screen).
    if (ModalRoute.of(context)?.isCurrent == false && _visible) {
      _hideQuietly();
    }
  }

  @override
  void dispose() {
    _stopTimers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide();
  }

  bool get _covered => ModalRoute.of(context)?.isCurrent == false;

  void _show(_Shown how, Offset anchor) {
    if (_covered) return;
    _stopTimers();
    if (how == _Shown.held) {
      _counts = Timer(
        HoldToReveal.revealedAfter,
        () => widget.onRevealed?.call(),
      );
    } else {
      widget.onRevealed?.call();
    }
    final wasVisible = _visible;
    setState(() {
      _shown = how;
      _anchor = anchor;
      _showings++;
    });
    _portal.show();
    if (!wasVisible) widget.onRevealChanged?.call(true);
  }

  void _hide() {
    if (!mounted || !_visible) return;
    _stopTimers();
    setState(() => _shown = null);
    widget.onRevealChanged?.call(false);
  }

  /// Hides while this widget is being rebuilt, without calling setState.
  void _hideQuietly() {
    _stopTimers();
    _shown = null;
    final changed = widget.onRevealChanged;
    if (changed != null) scheduleMicrotask(() => changed(false));
  }

  void _stopTimers() {
    _counts?.cancel();
    _counts = null;
  }

  /// [touch], in the cover's own box, as a share of its size.
  Offset _shareOf(Offset touch) {
    final size = context.size;
    if (size == null || size.isEmpty) return const Offset(0.5, 0.5);
    return Offset(touch.dx / size.width, touch.dy / size.height);
  }

  void _activate() {
    if (_shown == _Shown.activated) {
      _hide();
    } else {
      _show(_Shown.activated, const Offset(0.5, 0.5));
    }
  }

  void _release() {
    if (_shown != _Shown.held) return;
    final landed = _landed;
    final lifted = _lifted;
    if (_counts != null &&
        landed != null &&
        lifted != null &&
        fingerTime(landed, lifted) >=
            HoldToReveal.holdDelay + HoldToReveal.revealedAfter) {
      _stopTimers();
      widget.onRevealed?.call();
    }
    _hide();
  }

  /// A finger lands or lifts: only the card turning in place shows it.
  void _touch(bool down) {
    if (!widget.inPlace || _touching == down || !mounted) return;
    setState(() => _touching = down);
  }

  void _lostFocus() {
    if (_shown == _Shown.activated) _hide();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<Skin>();
    final skin = theme != null && context.dress.isPaper
        ? theme.dressedUp ?? theme
        : theme;
    final kind = GroundScope.maybeOf(context);
    final ground = skin != null && kind != null ? skin.ground(kind) : null;
    final focusColor = ground?.selection ?? Theme.of(context).focusColor;
    final focusWidth = skin?.shape.selectedRing ?? 3;
    final radius = BorderRadius.circular(skin?.shape.radius ?? 0);

    return Semantics(
      container: true,
      button: true,
      label: _visible
          ? widget.target
          : SpokenCopy.hidden.fill({'target': widget.target}),
      onTap: _activate,
      onDidLoseAccessibilityFocus: _lostFocus,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) =>
            setState(() => _focusHighlight = value),
        onFocusChange: (focused) {
          if (!focused) _lostFocus();
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _activate(),
          ),
        },
        child: OverlayPortal.overlayChildLayoutBuilder(
          controller: _portal,
          overlayChildBuilder: widget.inPlace || widget.away ? _nothing : _face,
          child: Container(
            // Dressed up the focus is a lift (the paper's shadow deepens), not
            // an outline.
            decoration: _focusHighlight && context.dress.isPaper
                ? BoxDecoration(
                    borderRadius: radius,
                    boxShadow: ground?.elevation.selected.litBy(context),
                  )
                : null,
            foregroundDecoration: _focusHighlight && !context.dress.isPaper
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: focusColor,
                      width: focusWidth,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  )
                : null,
            child: Listener(
              onPointerDown: (event) {
                _landed = event.timeStamp;
                _lifted = null;
                _touch(true);
              },
              onPointerUp: (event) {
                _lifted = event.timeStamp;
                _touch(false);
                _release();
              },
              onPointerCancel: (_) {
                _touch(false);
                _release();
              },
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                // Assistive technology shows it through the Semantics above.
                excludeFromSemantics: true,
                gestures: {
                  FingerTimedLongPress:
                      GestureRecognizerFactoryWithHandlers<
                        FingerTimedLongPress
                      >(
                        () => FingerTimedLongPress(
                          duration: HoldToReveal.holdDelay,
                        ),
                        (recognizer) => recognizer
                          ..onLongPressStart = ((details) => _show(
                            _Shown.held,
                            _shareOf(details.localPosition),
                          ))
                          ..onLongPressEnd = ((_) => _release())
                          ..onLongPressCancel = _release,
                      ),
                },
                // Hidden information: the cover sets the size, shown or not.
                child: HoldPress(
                  held: _shown == _Shown.held,
                  child: widget.inPlace ? _turned(context) : widget.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _nothing(BuildContext context, OverlayChildLayoutInfo _) =>
      const SizedBox.shrink();

  /// In place: the card turns over like paper ([PaperFlip]): the cover is
  /// its back, in its own box, and the face its other side. The cover
  /// sets the size, so nothing about the hidden state depends on the secret.
  Widget _turned(BuildContext context) => PaperFlip(
    turned: _visible,
    pressed: _touching,
    back: widget.cover,
    face: (context) => IgnorePointer(
      child: HeldFace(
        content: widget.face,
        page: _showings - 1,
        announce: _shown == _Shown.activated,
        fill: true,
      ),
    ),
  );

  /// The face, in the overlay, above the touch point, as tall as its words
  /// and portrait need and the room there allows (below it, clear of the
  /// thumb, when there is more room below). Placed at layout, from where the
  /// held card is in that frame, and never past the screen's edges: the face
  /// is always whole on screen.
  Widget _face(BuildContext context, OverlayChildLayoutInfo info) {
    // The portal stays open once used; while hidden it holds nothing.
    if (!_visible) return const SizedBox.shrink();
    final screen = info.overlaySize;
    final padding = MediaQuery.paddingOf(context);
    final width = HeldFace.widthFor(screen.width);
    final touch = MatrixUtils.transformPoint(
      info.childPaintTransform,
      Offset(
        _anchor.dx * info.childSize.width,
        _anchor.dy * info.childSize.height,
      ),
    );
    final top = padding.top + Space.sm;
    final bottom = screen.height - padding.bottom - Space.sm;
    // The face's lower edge above the touch, its upper edge below the thumb,
    // each kept inside the screen.
    final aboveEnds = math.min(touch.dy - HoldToReveal.gap, bottom);
    final belowStarts = math.max(touch.dy + HoldToReveal.thumb, top);
    final roomAbove = aboveEnds - top;
    final roomBelow = bottom - belowStarts;
    final double x = (touch.dx - width / 2).clamp(
      Space.gutter,
      math.max(Space.gutter, screen.width - Space.gutter - width),
    );
    final face = IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(0.0, math.max(roomAbove, roomBelow)),
        ),
        child: HeldFace(
          content: widget.face,
          page: _showings - 1,
          announce: _shown == _Shown.activated,
        ),
      ),
    );
    return Stack(
      children: [
        if (roomAbove >= roomBelow)
          Positioned(
            left: x,
            width: width,
            bottom: screen.height - aboveEnds,
            child: face,
          )
        else
          Positioned(left: x, width: width, top: belowStarts, child: face),
      ],
    );
  }
}
