import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/card_link.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';
import 'package:midnight_village/features/game/domain/night_timeline.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_window.dart';
import 'package:midnight_village/features/game/presentation/end/end_foot.dart';
import 'package:midnight_village/features/game/presentation/end/end_night.dart';
import 'package:midnight_village/features/game/presentation/end/end_night_links.dart';

// The rules a link of "What happened" keeps, read off the screen as drawn
// (docs/specs/frontend/end-board.md, section 8): no coordinate is pinned.
// Every thread of the step shown has its link; each end lies on the edge of
// the right card, as that card is drawn (turned, lifted), within a point;
// the thread stays in the board's window, off its own two cards, and
// crosses no other card (its name and strip are on it; a card the step
// lifted a card over is under the step) and no seal; a move
// has a head at both ends, a look a dot at the card seen, a team a dot at
// each.

/// What is wrong with the links of the step on screen, one line each.
List<String> nightLinkFaults(WidgetTester tester) {
  final scope = find.byType(EndNightScope);
  if (scope.evaluate().isEmpty) return const [];
  final night = tester.widget<EndNightScope>(scope).notifier!;
  final step = night.current;
  if (step == null) return const [];
  final faults = <String>[];
  final drawn = find.byType(NightLinks);
  if (drawn.evaluate().isEmpty) {
    return [if (step.threads.isNotEmpty) '${night.line}: no links drawn'];
  }
  final links = tester.widget<NightLinks>(drawn).links;
  final box = tester.renderObject<RenderBox>(drawn);
  if (links.length != step.threads.length) {
    faults.add(
      '${night.line}: ${links.length} links for '
      '${step.threads.length} threads',
    );
  }

  LaidCard? cardOf(CardPlace place) {
    final context = night.placeKey(place).currentContext;
    final card = context?.findRenderObject() as RenderBox?;
    if (card == null || !card.attached || !card.hasSize) return null;
    final faces = find.descendant(
      of: find.byKey(night.placeKey(place)),
      matching: find.byType(BoardCard),
    );
    final angle = faces.evaluate().isEmpty
        ? 0.0
        : tester.widget<BoardCard>(faces.first).angle;
    return LaidCard(card.localToGlobal(Offset.zero) & card.size, angle);
  }

  final window = tester.getRect(find.byType(EndBoardWindow));
  final roof = tester.getRect(find.byType(BoardRoof));
  final foot = tester.getRect(find.byType(EndFootBand));
  final room = Rect.fromLTRB(
    window.left,
    roof.bottom,
    window.right,
    foot.top - EndMetrics.lip,
  ).inflate(0.5);
  final seals = [
    for (final e
        in find
            .descendant(
              of: find.byType(NightBoard),
              matching: find.byType(YouSeal),
            )
            .evaluate())
      tester.getRect(find.byWidget(e.widget)),
  ];
  for (final (:from, :to, :link) in links) {
    final why = '${night.line}: ${_named(from)} to ${_named(to)}';
    final a = cardOf(from), b = cardOf(to);
    if (a == null || b == null) {
      faults.add('$why: a card is not drawn');
      continue;
    }
    final points = [
      for (final p in link.route.sample(TwinePainter.steps))
        box.localToGlobal(p),
    ];
    if (a.edgeDistance(points.first) > 1) {
      faults.add('$why: starts ${points.first} off its card\'s edge');
    }
    if (b.edgeDistance(points.last) > 1) {
      faults.add('$why: ends ${points.last} off its card\'s edge');
    }
    // Every other card on the board, but one the step lifted a card over
    // (it lies under the step's cards, as the fit pass lifts them).
    final mine = [
      for (final place in step.places) ?cardOf(place)?.bounds.deflate(2),
    ];
    final others = [
      for (final place in night.placed)
        if (place != from && place != to)
          if (cardOf(place) case final card?)
            if (room.overlaps(card.bounds) && !mine.any(card.bounds.overlaps))
              card,
    ];
    final inner = points.sublist(1, points.length - 1);
    if (!points.every(room.contains)) {
      faults.add('$why: leaves the board\'s window $room');
    }
    if (inner.any(
      (p) => a.contains(p, inset: 0.5) || b.contains(p, inset: 0.5),
    )) {
      faults.add('$why: runs under its own card');
    }
    if (inner.any((p) => others.any((c) => c.contains(p)))) {
      faults.add('$why: crosses another card (clear: ${link.clear})');
    }
    if (points.any((p) => seals.any((s) => s.contains(p)))) {
      faults.add('$why: runs under a seal');
    }
    final kind = linkKindOf(step.kind);
    final ends = switch (kind) {
      LinkKind.take || LinkKind.swap => (TwineEnd.head, TwineEnd.head),
      LinkKind.look => (TwineEnd.none, TwineEnd.dot),
      LinkKind.team => (TwineEnd.dot, TwineEnd.dot),
    };
    if (link.kind != kind || (link.start, link.end) != ends) {
      faults.add('$why: ends ${link.start} and ${link.end} for a $kind');
    }
  }
  return faults;
}

String _named(CardPlace place) => switch (place) {
  PlayerPlace(:final playerId) => 'player $playerId',
  CenterPlace(:final index) => 'middle card $index',
};
