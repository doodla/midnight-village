import 'package:flutter/widgets.dart';

/// How a screen is dressed. [plain] is the look the game has today; [paper] is
/// the "dressed up" pass: paper that is torn, grained and turned a hair, pinned
/// slips, banners, the plaque button, and a mood of light behind the screen.
///
/// The owner chooses per screen. A screen asks with `ScreenFrame(dress:)`; the
/// frame declares it as a [DressScope] and every shared part reads it through
/// `context.skin`, which gives a dressed skin under [paper] (its colours,
/// shadows, corners and angles) and the part's `context.dress` for what it
/// draws or leaves out. Nothing is dressed unless a screen asks: with no scope
/// above, a part is plain and draws exactly as it always did.
enum Dress {
  plain,
  paper;

  bool get isPaper => this == Dress.paper;
}

/// Declares the [Dress] of a subtree (`ScreenFrame` does, from its `dress`).
class DressScope extends InheritedWidget {
  const DressScope({super.key, required this.dress, required super.child});

  final Dress dress;

  /// The dress of [context]: plain where no scope is declared.
  static Dress of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DressScope>()?.dress ??
      Dress.plain;

  @override
  bool updateShouldNotify(DressScope old) => dress != old.dress;
}

extension DressContext on BuildContext {
  /// How the screen this widget is on is dressed.
  Dress get dress => DressScope.of(this);
}
