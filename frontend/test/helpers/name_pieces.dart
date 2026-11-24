import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/paper_banner.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/paper_seal.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/vote_slip.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';

import 'contract/contract_samples.dart';
import 'truncated_text.dart';

// A player's name, wherever the screen shows it, is whole and nothing lies on
// it: no piece of the kit drawn after it (a card, a tag, a slip, the banner, a
// seal) covers its words, and it is not cut at the side of the screen. The
// names come from the table (every name the server's samples seat, and every
// name the kit's pieces are given in the tree), the pieces from the kit's own
// types, so a screen lists nothing.

/// A piece of the kit: paper, a card, a tag, a slip, the banner, a seal, a
/// token. What a player sees as a thing lying on the screen.
bool isKitPiece(Widget w) =>
    w is PaperPiece ||
    w is PaperCard ||
    w is BoardCard ||
    w is BoardCardBack ||
    w is FaceDownCard ||
    w is RoleCard ||
    w is PaperSlip ||
    w is BannerSlice ||
    w is PaperBanner ||
    w is VoteTag ||
    w is YouSeal ||
    w is DeathRibbon ||
    w is PaperSeal ||
    w is PlayerToken;

Set<String>? _sampleNames;

/// Every name the server's recorded samples seat at a table.
Set<String> sampleNames() => _sampleNames ??= {
  for (final file in ContractSamples.dir.listSync(recursive: true))
    if (file is File && file.path.endsWith('.json'))
      for (final m in RegExp(
        r'"display_name":\s*"([^"]+)"',
      ).allMatches(file.readAsStringSync()))
        m.group(1)!,
};

/// The names the kit's pieces are given in the tree now (a long name a
/// fixture seats is here too).
Set<String> _treeNames() => {
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w is PlayerRow ||
                w is VoteSlip ||
                w is BoardCard ||
                w is BoardCardBack ||
                w is VoteTag ||
                (w is FaceDownCard && !w.youName),
          )
          .evaluate())
    if (switch (e.widget) {
          PlayerRow(:final name) ||
          VoteSlip(:final name) ||
          VoteTag(:final name) => name,
          BoardCard(:final name) || BoardCardBack(:final name) => name,
          FaceDownCard(:final ownerName) => ownerName,
          _ => null,
        }
        case final name? when name.trim().isNotEmpty)
      name.trim(),
};

RegExp? _namesPattern(Set<String> names) {
  if (names.isEmpty) return null;
  final alternatives = (names.toList()..sort((a, b) => b.length - a.length))
      .map(RegExp.escape)
      .join('|');
  return RegExp('(?<![\\p{L}])($alternatives)(?![\\p{L}])', unicode: true);
}

/// The words of [paragraph] on the screen, turned as drawn: each line's
/// glyphs, less the air above and below the letters (a quarter of the line
/// each way), so a piece that only touches a line's leading is not "on" it.
Rect _glyphs(RenderParagraph paragraph) {
  final length = paragraph.text.toPlainText().length;
  Rect? all;
  for (final b in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  )) {
    final r = b.toRect();
    final letters = Rect.fromLTRB(
      r.left,
      r.top + r.height / 4,
      r.right,
      r.bottom - r.height / 4,
    );
    all = all == null ? letters : all.expandToInclude(letters);
  }
  return MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    all ?? Offset.zero & paragraph.size,
  );
}

Rect _own(Element e) {
  final box = e.renderObject;
  if (box is! RenderBox || !box.hasSize || !box.attached) return Rect.zero;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

bool _current(Element e) => ModalRoute.of(e)?.isCurrent ?? true;

/// [e] is part of what a hold is showing: the kit's [HeldFace] (which
/// `HoldToReveal` draws only while the finger is down), anything in it, and
/// the paper it is framed in. It is there to be read over the screen and goes
/// when the finger lifts, so it may lie on a name, a card or the main action
/// (the coordinator's decision, 24 November 2026). It is still held to its
/// own rules: whole on the screen ([heldFaceProblems]), its words not cut
/// (the cut-text rule every state keeps).
bool heldOpen(Element e) {
  if (e.widget is HeldFace) return true;
  if (e.findAncestorWidgetOfExactType<HeldFace>() != null) return true;
  var holds = false;
  void look(Element child) {
    if (holds) return;
    if (child.widget is HeldFace) {
      holds = true;
      return;
    }
    child.visitChildren(look);
  }

  e.visitChildren(look);
  return holds;
}

/// What is wrong with a held face itself: it is whole on the screen.
List<String> heldFaceProblems(Size screen) {
  final all = (Offset.zero & screen).inflate(0.5);
  return [
    for (final e in find.byType(HeldFace).evaluate())
      if (_own(e) case final r
          when !all.contains(r.topLeft) || !all.contains(r.bottomRight))
        'the held face is not whole on the screen: $r',
  ];
}

/// What is wrong with the players' names on the tree as drawn, one line each.
List<String> nameProblems(WidgetTester tester, Size screen) {
  final pattern = _namesPattern({...sampleNames(), ..._treeNames()});
  if (pattern == null) return const [];
  final order = <Element, int>{};
  final pieces = <Element>[];
  void walk(Element e) {
    order[e] = order.length;
    if (isKitPiece(e.widget)) pieces.add(e);
    e.visitChildren(walk);
  }

  final root = tester.binding.rootElement;
  if (root == null) return const [];
  walk(root);
  // Every name drawn, in the order painted.
  final drawn = <(Element, RenderParagraph, String, Rect)>[];
  for (final e in find.byType(RichText).evaluate()) {
    final paragraph = e.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    if (paragraph.size.isEmpty || isUnseen(e, paragraph) || !_current(e)) {
      continue;
    }
    final name = pattern.firstMatch(paragraph.text.toPlainText())?.group(1);
    if (name != null) drawn.add((e, paragraph, name, _glyphs(paragraph)));
  }
  drawn.sort((a, b) => (order[a.$1] ?? -1).compareTo(order[b.$1] ?? -1));
  final problems = <String>[];
  final screenRect = Offset.zero & screen;
  for (final (i, (e, paragraph, name, words)) in drawn.indexed) {
    final text = paragraph.text.toPlainText().replaceAll('\n', ' ');
    final scrollable = Scrollable.maybeOf(e);
    if (scrollable == null) {
      if (!screenRect.inflate(0.5).contains(words.topLeft) ||
          !screenRect.inflate(0.5).contains(words.bottomRight)) {
        problems.add('$name is cut by the edge of the screen: $words');
      }
    } else {
      final port = _own(scrollable.context as Element).intersect(screenRect);
      final down =
          scrollable.axisDirection == AxisDirection.down ||
          scrollable.axisDirection == AxisDirection.up;
      final across = down
          ? words.left < port.left - 0.5 || words.right > port.right + 0.5
          : words.top < port.top - 0.5 || words.bottom > port.bottom + 0.5;
      if (across) problems.add('$name is cut at the side: $words in $port');
      // Scrolled away: not on the screen to be covered.
      if (!liesOnRect(words, port)) continue;
    }
    // The same name drawn after it on the same place stands in for it (a
    // card lifted off its place in a replay): what is seen is that one.
    final standIn = drawn
        .skip(i + 1)
        .any((d) => d.$3 == name && liesOnRect(d.$4, words));
    if (standIn) continue;
    // A name in what a hold shows is drawn above the whole screen (the kit
    // paints it in the overlay, wherever it sits in the tree): nothing the
    // screen draws after it lies on it.
    if (heldOpen(e)) continue;
    final at = order[e] ?? -1;
    for (final piece in pieces) {
      if ((order[piece] ?? -1) <= at || !_current(piece)) continue;
      // What a hold shows may lie on a name while the finger is down.
      if (heldOpen(piece)) continue;
      // A piece fixed over a scrolling list (a banner, a foot): the name
      // scrolls under it, as a list's rows do under its edges.
      if (scrollable != null && Scrollable.maybeOf(piece) != scrollable) {
        continue;
      }
      final body = piece.renderObject;
      if (body == null || isUnseen(piece, body)) continue;
      if (liesOnRect(_own(piece), words)) {
        problems.add(
          '$name ("$text") is covered by a ${piece.widget.runtimeType}: '
          '${_own(piece)} on $words',
        );
        break;
      }
    }
  }
  return problems;
}

/// Two boxes lie on each other by more than a hair.
bool liesOnRect(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 1 && i.height > 1;
}
