import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'elevation.dart';

/// What a part of the screen is laid on. Night screens are dark and day
/// screens light, so the phase reads from across the table; paper is the
/// ground inside a paper card on either.
enum GroundKind { night, day, paper }

/// The colour roles of one ground, and the shadows things cast on it. Every
/// role is relative to the ground: `text` is the text colour on this ground,
/// `paper` the fill of a paper card laid on it, and so on.
@immutable
class Ground {
  const Ground({
    required this.ground,
    required this.panel,
    required this.text,
    required this.quietText,
    required this.faintText,
    required this.hairline,
    required this.idle,
    required this.outline,
    required this.edge,
    required this.shadow,
    required this.paper,
    required this.paperEdge,
    required this.accent,
    required this.onAccent,
    this.accentEdge,
    required this.selection,
    required this.mark,
    required this.onMark,
    required this.danger,
    required this.onDanger,
    required this.dangerText,
    required this.dangerLine,
    required this.disabled,
    required this.onDisabled,
    required this.elevation,
  });

  /// The ground itself.
  final Color ground;

  /// A quiet well or panel set into the ground (a timer box, an info box).
  final Color panel;

  /// Text and icons.
  final Color text;

  /// Secondary text: labels, hints, counts.
  final Color quietText;

  /// Text of things that are present but switched off (a role not in the
  /// deck).
  final Color faintText;

  /// Rules, rings of inactive things, the empty part of a progress bar.
  final Color hairline;

  /// The ring of a player who has not done the thing being counted yet.
  final Color idle;

  /// The stroke of outline buttons and inputs.
  final Color outline;

  /// The line drawn around cut shapes when the skin's shape gives them one.
  final Color edge;

  /// The hard shadow colour of things lying on this ground.
  final Color shadow;

  /// The fill of a paper card laid on this ground.
  final Color paper;

  /// The edge of a paper stack, seen below a slab.
  final Color paperEdge;

  /// The single warm accent (lantern amber): the fill of the one primary
  /// button on a screen, and of nothing else (first-time play spec, copy
  /// rule 10). The same on every ground.
  final Color accent;
  final Color onAccent;

  /// The line round the accent where it is too close to this ground to
  /// stand off it (amber on dawn grey is 1.55:1); null where it stands off.
  final Color? accentEdge;

  /// The outline round the thing currently selected, which also lifts: bone
  /// on night, ink on day and paper. Never the accent, and never a fill.
  final Color selection;

  /// Counts on cards (a role's count in the deck) and the ring of the "My
  /// night" card.
  final Color mark;
  final Color onMark;

  /// Danger and the Werewolf team, as a fill.
  final Color danger;
  final Color onDanger;

  /// Danger as text on this ground.
  final Color dangerText;

  /// Danger as a thin line on this ground.
  final Color dangerLine;

  /// A control that cannot be used now.
  final Color disabled;
  final Color onDisabled;

  final GroundElevation elevation;
}
