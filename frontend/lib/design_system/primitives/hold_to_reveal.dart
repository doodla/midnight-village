import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Secret information behind press-and-hold (design brief section 3, rule 2):
/// [cover] shows until the player presses and holds, [secret] while they
/// hold, and the cover again the moment they let go. The secret is built only
/// while shown, so it is not in the tree (or read out) otherwise.
///
/// Holding is not possible for everyone, so a screen reader's activate, a
/// switch or the keyboard (Enter, Space) toggles it instead: shown until
/// activated again. Either way it hides when the app leaves the foreground,
/// so it is never showing when the phone is picked up again.
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

  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal>
    with WidgetsBindingObserver {
  var _revealed = false;

  /// Shown by a toggle (not a hold), so letting go of a pointer keeps it.
  var _toggled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _set(false);
  }

  void _set(bool revealed, {bool toggled = false}) {
    _toggled = revealed && toggled;
    if (revealed == _revealed) return;
    setState(() => _revealed = revealed);
    widget.onRevealChanged?.call(revealed);
  }

  void _toggle() => _set(!_revealed, toggled: true);

  void _release() {
    if (!_toggled) _set(false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      hint: _revealed
          ? 'Activate to hide'
          : 'Press and hold, or activate, to show',
      onTap: _toggle,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _toggle(),
          ),
        },
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
                      ..onLongPressStart = ((_) => _set(true))
                      ..onLongPressEnd = ((_) => _release())
                      ..onLongPressCancel = _release,
                  ),
            },
            child: _revealed ? widget.secret(context) : widget.cover,
          ),
        ),
      ),
    );
  }
}
