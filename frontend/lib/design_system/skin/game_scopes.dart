import 'package:flutter/widgets.dart';

import 'card_back.dart';
import 'card_back_scope.dart';
import 'dress.dart';
import 'ground.dart';
import 'ground_scope.dart';
import 'werewolf_portrait.dart';

/// Every inherited scope of a screen that content opened in another route
/// (a sheet, a dialog) must still see. A route opened on the root navigator
/// sits above the table shell, so nothing the shell or a frame declares
/// reaches it unless it is carried over by hand. This is the one place that
/// does it: [capture] reads them at the opening context, [wrap] declares them
/// again around the route's content. `showSkinSheet` and `showSkinDialog` use
/// it, and nothing else opens a route.
///
/// A new game-wide scope is added in three places in this file, [capture],
/// the fields and [wrap]; `game_scopes_test.dart` fails if a sheet misses one.
@immutable
class GameScopes {
  const GameScopes({
    required this.ground,
    required this.dress,
    required this.cardBack,
    required this.werewolf,
  });

  /// Reads every scope at [context] (the place the route is opened from).
  factory GameScopes.capture(BuildContext context) => GameScopes(
    ground: GroundScope.of(context),
    dress: DressScope.of(context),
    cardBack: CardBackScope.of(context),
    werewolf: WerewolfPortraitScope.of(context),
  );

  final GroundKind ground;
  final Dress dress;
  final CardBack cardBack;
  final WerewolfPortrait werewolf;

  /// [child] under the same scopes.
  Widget wrap(Widget child) => DressScope(
    dress: dress,
    child: CardBackScope(
      back: cardBack,
      child: WerewolfPortraitScope(
        portrait: werewolf,
        child: GroundScope(ground: ground, child: child),
      ),
    ),
  );
}
