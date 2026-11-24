import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/end_board.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';

// The end board's rules as checks on a plan (docs/specs/frontend/end-board.md,
// section 3, rule 9), shared by the domain tests (the stand-in measure,
// `end_board_plans.dart`) and the screen sweep on the real
// fonts (`endBoardSweep` in `test_screens/end_board_pages.dart`), so the two can never disagree silently:
// - the hard rule: what hangs on a card covers no other card and no name
//   ([coverFaults]), checked here on its own, not by the app's own check;
// - six or fewer give up nothing: a board of six or fewer that scrolls stands
//   at the tightest fit step whose pieces cover nothing ([expectGaveUpNothing]);
// - the opening rule ([expectOpensByTheRule]).

/// Every way a piece of [plan] breaks the hard rule, in words; empty when it
/// keeps it.
List<String> coverFaults(EndBoardPlan plan) {
  final faults = <String>[];
  for (final a in plan.cards) {
    final hung = <(String, Rect)>[
      if (a.dealtRect != null) ('dealt card', a.dealtRect!),
      if (a.ribbonRect != null) ('ribbon', a.ribbonRect!),
      if (a.sealRect != null) ('seal', a.sealRect!),
      if (a.pin != null) ('pin', a.pin!),
      for (final t in a.tags) ('tag of ${t.name}', t.rect),
    ];
    for (final (what, rect) in hung) {
      for (final b in plan.cards) {
        if (a.id == b.id) {
          // A tag, a seal or a ribbon never covers its own name.
          if (what != 'dealt card' &&
              what != 'pin' &&
              rect.overlaps(a.nameText)) {
            faults.add('${a.name}\'s $what covers its name');
          }
          continue;
        }
        if (rect.overlaps(b.leaned)) {
          faults.add('${a.name}\'s $what covers ${b.name}');
        }
        if (what.startsWith('tag') &&
            b.tags.any((t) => rect.overlaps(t.rect))) {
          faults.add('${a.name}\'s $what covers a tag of ${b.name}');
        }
      }
    }
    // A strand hangs in its card's column, every tag clear of the next.
    for (final t in a.tags) {
      for (final u in a.tags) {
        if (!identical(t, u) && t.rect.overlaps(u.rect)) {
          faults.add('${t.name}\'s and ${u.name}\'s tags touch');
        }
      }
      if (t.rect.left < a.column.left - 0.01 ||
          t.rect.right > a.column.right + 0.01) {
        faults.add('${t.name}\'s tag leaves ${a.name}\'s column');
      }
    }
  }
  for (final pick in plan.picks) {
    final slip = pick.slip;
    for (final c in plan.cards) {
      if (slip.overlaps(c.nameText)) {
        faults.add('the Hunter\'s slip covers ${c.name}\'s name');
      }
      if (c.tags.any((t) => slip.overlaps(t.rect))) {
        faults.add('the Hunter\'s slip covers a tag of ${c.name}');
      }
      if (c.id != pick.hunterId &&
          c.id != pick.pickId &&
          slip.overlaps(c.leaned)) {
        faults.add('the Hunter\'s slip covers ${c.name}');
      }
      for (final (what, part) in [
        ('seal', c.sealRect),
        ('ribbon', c.ribbonDrawn),
      ]) {
        if (part != null && slip.overlaps(part)) {
          faults.add('the Hunter\'s slip covers ${c.name}\'s $what');
        }
      }
    }
    if (slip.left < 0 || slip.right > plan.boardWidth) {
      faults.add('the Hunter\'s slip leaves the board');
    }
  }
  return faults;
}

/// Six or fewer fit one screen as far as they can: IF a board of six or
/// fewer scrolls, THEN every fit step tighter than its own would break the
/// hard rule (it gave up nothing it could have given).
void expectGaveUpNothing(EndBoardPlan plan, {String name = ''}) {
  if (plan.cards.length > EndMetrics.fitsUpTo || !plan.scrolls) return;
  final tighter = EndFit.levels.skip(EndFit.levels.indexOf(plan.fit) + 1);
  expect(
    plan.refused.map((p) => p.fit),
    tighter,
    reason: '$name scrolls at ${plan.fit} without trying the steps after it',
  );
  for (final p in plan.refused) {
    expect(
      coverFaults(p),
      isNotEmpty,
      reason: '$name scrolls at ${plan.fit}, yet ${p.fit} covers nothing',
    );
  }
}

/// The opening rule. A board that does not scroll opens at its top. One that
/// scrolls and opens down the board at all has a card cut by the eave, at
/// least [EndMetrics.cutLeast] of it showing (more above). And it shows whole,
/// above the foot's lip, the most of this list that some such opening can:
/// the hanged with what hangs on them and your card; the hanged with what
/// hangs on them; the hanged's cards; the vote's dead with their tags; the
/// vote's dead's cards.
void expectOpensByTheRule(EndBoardPlan plan, {String name = ''}) {
  final top = plan.initialScroll;
  final most = plan.boardHeight - plan.viewHeight;
  expect(top, greaterThanOrEqualTo(0), reason: name);
  expect(top, lessThanOrEqualTo(most + 0.01), reason: name);
  if (!plan.scrolls) {
    expect(top, 0, reason: name);
    return;
  }
  bool cutAt(double s) => plan.cards.any(
    (c) =>
        c.leaned.top <= s - 2 + 0.01 &&
        c.leaned.bottom >= s + EndMetrics.cutLeast - 0.01,
  );
  // Whole in the window at scroll [s], [EndMetrics.clear] inside its edges,
  // give or take [slack].
  bool inView(double s, Rect r, {double slack = 0.5}) =>
      r.top >= s + EndMetrics.clear - slack &&
      r.bottom <=
          s + plan.viewHeight - EndMetrics.lip - EndMetrics.clear + slack;
  // Some opening the rule allows shows all of [boxes].
  bool canShow(List<Rect> boxes) {
    for (var s = 0.0; s <= most; s += 0.5) {
      if ((s == 0 || cutAt(s)) &&
          boxes.every((r) => inView(s, r, slack: -0.01))) {
        return true;
      }
    }
    return false;
  }

  if (top > 0) {
    expect(
      cutAt(top),
      isTrue,
      reason: '$name: opened down the board with no card cut by the eave',
    );
  }
  final hanged = plan.cards.where((c) => c.hanged).toList();
  if (hanged.isEmpty) return;
  final you = plan.cards.firstWhere((c) => c.you);
  final yours = you.sealRect == null
      ? you.leaned
      : you.leaned.expandToInclude(you.sealRect!);
  final voted = hanged.where((c) => !c.pickedByHunter);
  for (final (what, boxes) in [
    ('the hanged and your card', [...hanged.map((c) => c.reach), yours]),
    ('the hanged and their tags', [...hanged.map((c) => c.reach)]),
    ('the hanged', [...hanged.map((c) => c.leaned)]),
    ('the vote\'s dead and their tags', [...voted.map((c) => c.reach)]),
    ('the vote\'s dead', [...voted.map((c) => c.leaned)]),
  ]) {
    if (!canShow(boxes)) continue;
    expect(
      boxes.every((r) => inView(top, r)),
      isTrue,
      reason: '$name: it could show $what whole, and does not (at $top)',
    );
    return;
  }
}
