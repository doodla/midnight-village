import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'player_token.dart';

/// "3 of 5 ready" as a row of slots and the words. Plain pips count (S04);
/// token pips ([ProgressPips.tokens]) show who (S07, S08, S09). In a skin
/// whose pips stretch, plain pips share the row's width as bars.
class ProgressPips extends StatelessWidget {
  const ProgressPips({
    super.key,
    required this.done,
    required this.total,
    required this.label,
    this.centred = false,
  }) : tokens = const [],
       doneTokens = const {},
       tokenSize = TokenSize.pip;

  /// One token per player, those in [done] at full strength.
  const ProgressPips.tokens({
    super.key,
    required this.tokens,
    required Set<TokenId> done,
    required this.label,
    this.tokenSize = TokenSize.pip,
    this.centred = false,
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

  /// [TokenSize.waiting] at night (S07), [TokenSize.pip] by day (S08, S09).
  final TokenSize tokenSize;

  /// Centred under a centred screen (S04, S07); otherwise from the start.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final plain = tokens.isEmpty;
    final words = Padding(
      padding: const EdgeInsetsDirectional.only(start: Space.xs),
      child: Text(
        label,
        style: (plain ? skin.typography.small : skin.typography.smallStrong)
            .copyWith(color: ground.quietText),
      ),
    );
    final Widget row;
    if (plain && skin.shape.pipStretch) {
      row = Row(
        spacing: Space.sm,
        children: [
          for (var i = 0; i < total; i++)
            Expanded(child: _Pip(filled: i < done)),
          // The words keep up to half the row when the text is large.
          Flexible(flex: total, child: words),
        ],
      );
    } else {
      row = Wrap(
        alignment: centred ? WrapAlignment.center : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          if (plain)
            for (var i = 0; i < total; i++) _Pip(filled: i < done)
          else
            for (final token in tokens)
              PlayerToken(
                token,
                size: tokenSize,
                waiting: !doneTokens.contains(token),
              ),
          words,
        ],
      );
    }
    return Semantics(label: label, excludeSemantics: true, child: row);
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
      width: shape.pipStretch ? null : shape.pip.width,
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
