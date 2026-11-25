import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../primitives/chips.dart';
import '../primitives/deck_pile.dart';
import '../primitives/face_down_card.dart';
import '../primitives/hold_to_reveal.dart';
import '../primitives/icon_action.dart';
import '../primitives/paper_scrap.dart';
import '../primitives/player_row.dart';
import '../primitives/primary_button.dart';
import '../primitives/role_card.dart';
import '../primitives/secondary_button.dart';
import '../primitives/text_action.dart';
import '../primitives/value_stepper.dart';
import '../primitives/vote_slip.dart';

/// Marks the field recorder's own strip: a touch on it is not recorded.
class PerfOwn extends StatelessWidget {
  const PerfOwn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The kind of a kit control, by its type (never its words: a label can
/// hold a player's name).
String? _kind(Widget widget) => switch (widget) {
  PerfOwn() => 'perf',
  PrimaryButton() => 'main_button',
  SecondaryButton() => 'second_button',
  TextAction() => 'text_action',
  IconAction() => 'icon_action',
  PaperScrap() => 'scrap',
  PresetChip() => 'preset',
  PlayerRow() => 'player_row',
  VoteSlip() => 'vote_slip',
  FaceDownCard() => 'card',
  RoleCard() => 'role_card',
  DeckPile() => 'deck_pile',
  ValueStepper() => 'stepper',
  HoldToReveal() => 'hold',
  EditableText() => 'text_field',
  _ => null,
};

/// What a finger going down at [position] reaches: the innermost kit control
/// under it, `other` for something else that takes a touch, null for none.
///
/// The hit test the framework makes anyway, then the one path of elements
/// down to what was hit (each step looks only at the children that lead to
/// it), so it costs a few thousand steps, once per touch, and only while the
/// recorder is on.
String? controlAt(Offset position, int viewId) {
  final result = HitTestResult();
  RendererBinding.instance.hitTestInView(result, position, viewId);
  RenderObject? hit;
  var touchable = false;
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    hit ??= target;
    if (target is RenderPointerListener ||
        target is RenderSemanticsGestureHandler) {
      touchable = true;
    }
  }
  if (hit == null) return null;
  final above = <RenderObject>{};
  for (RenderObject? r = hit; r != null; r = r.parent) {
    above.add(r);
  }
  String? kind;
  Element? at = WidgetsBinding.instance.rootElement;
  while (at != null) {
    kind = _kind(at.widget) ?? kind;
    Element? next;
    at.visitChildren((child) {
      if (next != null) return;
      final r = child.renderObject;
      if (r != null && above.contains(r)) next = child;
    });
    at = next;
  }
  return kind ?? (touchable ? 'other' : null);
}
