import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'player_token.dart';

/// "3 of 5 ready" as a row of slots and the words. Plain pips count; token
/// pips ([ProgressPips.tokens]) show who.
class ProgressPips extends StatelessWidget {
  const ProgressPips({
    super.key,
    required this.done,
    required this.total,
    required this.label,
  }) : tokens = const [],
       doneTokens = const {},
       tokenSize = 0;

  /// One token per player, those in [done] at full strength.
  const ProgressPips.tokens({
    super.key,
    required this.tokens,
    required Set<TokenId> done,
    required this.label,
    this.tokenSize = 30,
  }) : doneTokens = done,
       done = 0,
       total = 0;

  /// Plain pips: how many of [total] are filled.
  final int done;
  final int total;

  /// The words after the pips ("3 of 5 ready"), also what is read out.
  final String label;

  final List<TokenId> tokens;
  final Set<TokenId> doneTokens;
  final double tokenSize;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final pips = tokens.isEmpty
        ? [for (var i = 0; i < total; i++) _Pip(filled: i < done)]
        : [
            for (final token in tokens)
              PlayerToken(
                token,
                size: tokenSize,
                dimmed: !doneTokens.contains(token),
              ),
          ];
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: skin.spacing.sm,
        runSpacing: skin.spacing.sm,
        children: [
          ...pips,
          Padding(
            padding: EdgeInsetsDirectional.only(start: skin.spacing.xs),
            child: Text(
              label,
              style: skin.typography.small.copyWith(color: ground.quietText),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = context.skin.shape;
    final ground = context.ground;
    final outlined = !filled && shape.pipEmptyStroke > 0;
    return Container(
      width: shape.pip.width,
      height: shape.pip.height,
      decoration: BoxDecoration(
        color: filled
            ? ground.text
            : outlined
            ? null
            : ground.hairline,
        border: outlined
            ? Border.all(color: ground.text, width: shape.pipEmptyStroke)
            : null,
        borderRadius: BorderRadius.circular(
          shape.corner(shape.pip.height, shape.pipRoundness),
        ),
      ),
    );
  }
}
