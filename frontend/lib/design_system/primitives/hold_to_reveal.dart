import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../skin/ground_scope.dart';
import '../skin/skin.dart';

/// Secret information behind press-and-hold (design brief section 3, rule 2):
/// [cover] shows until the player presses and holds, [secret] while they
/// hold, and the cover again the moment they let go.
///
/// Holding is not possible for everyone, so a screen reader's activate, a
/// switch or the keyboard (Enter, Space) toggles it instead. A toggled secret
/// still hides by itself: when focus moves away from it, when another route
/// covers its screen (a dialog's scrim never has the secret faintly behind
/// it), when the app leaves the foreground, and after [toggleTimeout]. A
/// held one hides on all but the timeout, and on letting go.
///
/// Nothing about the hidden state depends on the secret: the secret is built
/// only while shown (it is not in the tree, or read out, otherwise), and the
/// widget is always the cover's size, the secret being fitted into it, so
/// the space it takes says nothing about what is behind it. Show something
/// whose art is precached (`precacheArt`), so revealing it takes the same
/// time whatever it is and fetches nothing.
class HoldToReveal extends StatefulWidget {
  const HoldToReveal({
    super.key,
    required this.cover,
    required this.secret,
    required this.semanticLabel,
    this.onRevealChanged,
  });

  final Widget cover;
  final WidgetBuilder secret;

  /// What this is ("Your card"); the hint says how to reveal it.
  final String semanticLabel;

  /// Told each time the secret is shown (true) or hidden (false).
  final ValueChanged<bool>? onRevealChanged;

  /// How long a press must last before it counts as a hold, so a scroll
  /// that starts on the card does not flash it.
  static const holdDelay = kPressTimeout;

  /// How long a toggled secret stays shown.
  static const toggleTimeout = Duration(seconds: 8);

  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal>
    with WidgetsBindingObserver {
  var _revealed = false;

  /// Shown by a toggle (not a hold), so letting go of a pointer keeps it.
  var _toggled = false;
  var _focusHighlight = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Another route over this one (a dialog, a sheet, the next screen).
    if (ModalRoute.of(context)?.isCurrent == false && _revealed) {
      _hideQuietly();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _set(false);
  }

  void _set(bool revealed, {bool toggled = false}) {
    _toggled = revealed && toggled;
    _timeout?.cancel();
    _timeout = _toggled ? Timer(HoldToReveal.toggleTimeout, _hide) : null;
    if (revealed == _revealed) return;
    setState(() => _revealed = revealed);
    widget.onRevealChanged?.call(revealed);
  }

  /// Hides while this widget is being rebuilt, without calling setState.
  void _hideQuietly() {
    _revealed = false;
    _toggled = false;
    _timeout?.cancel();
    _timeout = null;
    final changed = widget.onRevealChanged;
    if (changed != null) scheduleMicrotask(() => changed(false));
  }

  void _hide() {
    if (mounted) _set(false);
  }

  void _toggle() {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _set(!_revealed, toggled: true);
  }

  void _release() {
    if (!_toggled) _set(false);
  }

  void _lostFocus() {
    if (_toggled) _set(false);
  }

  @override
  Widget build(BuildContext context) {
    final skin = Theme.of(context).extension<Skin>();
    final kind = GroundScope.maybeOf(context);
    final ground = skin != null && kind != null ? skin.ground(kind) : null;
    final focusColor = ground?.selection ?? Theme.of(context).focusColor;
    final focusWidth = skin?.shape.selectedRing ?? 3;
    final radius = BorderRadius.circular(skin?.shape.radius ?? 0);

    final content = Stack(
      children: [
        // The cover always sets the size, shown or not.
        Visibility(
          visible: !_revealed,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: widget.cover,
        ),
        if (_revealed)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: Builder(builder: widget.secret),
            ),
          ),
      ],
    );

    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      hint: _revealed
          ? 'Activate to hide'
          : 'Press and hold, or activate, to show',
      onTap: _toggle,
      onDidLoseAccessibilityFocus: _lostFocus,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) =>
            setState(() => _focusHighlight = value),
        onFocusChange: (focused) {
          if (!focused) _lostFocus();
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _toggle(),
          ),
        },
        child: Container(
          foregroundDecoration: _focusHighlight
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
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              // Assistive technology toggles through the Semantics above.
              excludeFromSemantics: true,
              gestures: {
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: HoldToReveal.holdDelay,
                      ),
                      (recognizer) => recognizer
                        ..onLongPressStart = ((_) {
                          if (ModalRoute.of(context)?.isCurrent != false) {
                            _set(true);
                          }
                        })
                        ..onLongPressEnd = ((_) => _release())
                        ..onLongPressCancel = _release,
                    ),
              },
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
