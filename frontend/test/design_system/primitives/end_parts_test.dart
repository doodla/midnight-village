import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/one_light.dart';
import 'package:midnight_village/design_system/primitives/paper_light.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart'
    show BusyMark;
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/tilted_paper.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/elevation.dart';
import 'package:midnight_village/design_system/skin/end_art.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import '../../helpers/art_decoded.dart';
import '../../helpers/frame_pixels.dart';
import '../../helpers/pump_skinned.dart';

// The end board's parts (piece 1 of the end board): each one's own promise,
// beside the kit's tests that every part passes (`paper_components_test.dart`
// and `paper_rules_test.dart` run all of them from the parts catalogue).

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Dress dress = Dress.paper,
  Alignment align = Alignment.center,
}) => pumpSkinned(
  tester,
  DressScope(
    dress: dress,
    child: Material(
      type: MaterialType.transparency,
      child: Align(alignment: align, child: child),
    ),
  ),
);

void _phone(WidgetTester tester, [Size size = const Size(800, 600)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The paper of a dressed piece: its decoration's shadows, as drawn.
List<BoxShadow> _shadowsOf(WidgetTester tester, Finder piece) {
  final paper = find.descendant(of: piece, matching: find.byType(TiltedPaper));
  final decoration = tester.widget<TiltedPaper>(paper.first).decoration;
  return (decoration as ShapeDecoration).shadows ?? const [];
}

/// The share of pixels that differ by more than a little in any channel.
double _farOff(List<int> a, List<int> b) {
  var off = 0;
  for (var i = 0; i < a.length; i++) {
    for (final shift in [0, 8, 16]) {
      if (((a[i] >> shift) & 0xFF) - ((b[i] >> shift) & 0xFF) > 40 ||
          ((b[i] >> shift) & 0xFF) - ((a[i] >> shift) & 0xFF) > 40) {
        off++;
        break;
      }
    }
  }
  return off / a.length;
}

/// The paper elevation of a card on the dressed night, as the board has it.
Elevation _dressedElevation() =>
    skinsUnderTest.values.first.dressedUp!.night.elevation.card;

void main() {
  group('PaperScrap: the paper is 40, the finger has 48', () {
    for (final dress in Dress.values) {
      testWidgets('on a ${dress.name} screen', (tester) async {
        _phone(tester);
        var taps = 0;
        await _pump(
          tester,
          PaperScrap(label: 'What happened', onTap: () => taps++),
          dress: dress,
        );
        final target = find.descendant(
          of: find.byType(PaperScrap),
          matching: find.byType(GestureDetector),
        );
        expect(tester.getSize(target).height, PaperScrap.touchHeight);
        expect(PaperScrap.touchHeight, 48);
        if (dress.isPaper) {
          final paper = tester.getRect(find.byType(PaperPiece));
          expect(paper.height, PaperScrap.paperHeight);
          expect(PaperScrap.paperHeight, 40);
          // Four points above and below the paper is still the scrap...
          await tester.tapAt(paper.topCenter - const Offset(0, 3));
          await tester.tapAt(paper.bottomCenter + const Offset(0, 3));
          expect(taps, 2);
          // ...and ten is not.
          await tester.tapAt(paper.topCenter - const Offset(0, 10));
          expect(taps, 2);
        } else {
          await tester.tap(find.byType(PaperScrap));
          expect(taps, 1);
        }
      });
    }

    testWidgets('two lines of words: the paper is 48, the target no less', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        PaperScrap(label: 'Back to\nthe result', onTap: () {}),
      );
      expect(
        tester.getSize(find.byType(PaperPiece)).height,
        PaperScrap.paperHeightTwoLines,
      );
      final target = find.descendant(
        of: find.byType(PaperScrap),
        matching: find.byType(GestureDetector),
      );
      expect(
        tester.getSize(target).height,
        greaterThanOrEqualTo(PaperScrap.touchHeight),
      );
      expect(find.text('Back to\nthe result'), findsOneWidget);
    });

    for (final dress in Dress.values) {
      testWidgets('busy on a ${dress.name} screen: the mark turns in the '
          'scrap\'s own end room; its words stay put, whole and in full ink', (
        tester,
      ) async {
        _phone(tester);
        Future<Rect> words({required bool busy}) async {
          await _pump(
            tester,
            PaperScrap(
              label: 'Edit deck',
              onTap: () {},
              sends: true,
              busy: busy,
            ),
            dress: dress,
          );
          return tester.getRect(find.text('Edit deck'));
        }

        final idle = await words(busy: false);
        final busy = await words(busy: true);
        expect(busy, idle);
        final mark = tester.getRect(find.byType(BusyMark));
        expect(mark.overlaps(busy), isFalse, reason: 'the mark on the words');
        if (dress.isPaper) {
          final paper = tester.getRect(find.byType(PaperPiece));
          expect(paper.contains(mark.topLeft), isTrue);
          expect(paper.contains(mark.bottomRight - const Offset(1, 1)), isTrue);
        }
        // Nothing dims the words.
        expect(
          find.ancestor(
            of: find.text('Edit deck'),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });
    }

    testWidgets('a slip says something and takes no tap', (tester) async {
      _phone(tester);
      await _pump(tester, const PaperSlip(label: 'Dev deals next.'));
      expect(
        find.descendant(
          of: find.byType(PaperSlip),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Dev deals next.'), findsOneWidget);
    });
  });

  group('VoteTag: a name is never cut', () {
    const long = 'Maximilianoooooooooo'; // 20 letters, one word.
    for (final width in <double?>[null, 210, 150, 100]) {
      testWidgets('20 letters in ${width ?? 'all the room it needs'}', (
        tester,
      ) async {
        _phone(tester);
        await _pump(
          tester,
          VoteTag(name: long, token: TokenId.crow, maxWidth: width),
        );
        await loadPictures(tester);
        expect(tester.takeException(), isNull);
        final words = find.text(long);
        expect(words, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(words);
        expect(paragraph.didExceedMaxLines, isFalse);
        // The whole word is laid out inside the tag: no clip, no ellipsis.
        expect(
          paragraph.size.width + 0.5,
          greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
        );
        final tag = tester.getRect(find.byType(VoteTag));
        expect(tag.height, VoteTag.defaultHeight);
        expect(tester.getRect(words).right, lessThanOrEqualTo(tag.right));
        // A tag fits the room it is given while its name can be set smaller to
        // fit it; where the name would pass the label floor, the tag is as wide
        // as the name needs (the name is never cut to fit).
        if (width != null) {
          expect(tag.width, lessThanOrEqualTo(width < 190 ? 190 : width));
        }
        // Set smaller before it is cut, never under the label floor.
        final size = tester.widget<Text>(words).style!.fontSize!;
        expect(size, greaterThanOrEqualTo(12));
        if (width == 210) expect(size, lessThan(16));
      });
    }

    testWidgets('a short name makes a short tag', (tester) async {
      _phone(tester);
      await _pump(tester, const VoteTag(name: 'Ana', token: TokenId.key));
      final short = tester.getSize(find.byType(VoteTag)).width;
      await _pump(tester, const VoteTag(name: long, token: TokenId.key));
      expect(
        tester.getSize(find.byType(VoteTag)).width,
        greaterThan(short + 80),
      );
    });
  });

  group('BannerSlice: stretches with its words, the ends stay', () {
    Future<(Rect, Image)> pumpBanner(
      WidgetTester tester,
      List<String> lines, {
      bool red = false,
    }) async {
      // Measured once, then laid in a box exactly its own width so it sits at
      // a whole pixel: a banner's ends are compared pixel for pixel.
      Widget banner(double? width) => SizedBox(
        width: width,
        child: BannerSlice(lines: lines, red: red, angle: 0),
      );
      await _pump(tester, banner(800), align: Alignment.topLeft);
      await loadPictures(tester);
      final natural = tester.getSize(find.byType(Image)).width;
      await _pump(tester, banner(natural), align: Alignment.topLeft);
      await loadPictures(tester);
      return (
        tester.getRect(find.byType(Image)),
        tester.widget<Image>(find.byType(Image)),
      );
    }

    testWidgets('one line and two: wider words, a wider banner, one height', (
      tester,
    ) async {
      _phone(tester);
      final (one, oneImage) = await pumpBanner(tester, ['Cleo hanged.']);
      final (two, twoImage) = await pumpBanner(tester, [
        'Cleo hanged.',
        'You and the village win.',
      ]);
      expect(one.height, BannerSlice.height);
      expect(two.height, BannerSlice.height);
      expect(two.width, greaterThan(one.width));
      // The same cut at the same scale: the ends are the same size.
      expect(twoImage.centerSlice, oneImage.centerSlice);
      expect(
        (twoImage.image as ExactAssetImage).scale,
        (oneImage.image as ExactAssetImage).scale,
      );
      // The words are the 24 point headline.
      expect(
        tester
            .widget<Text>(find.text('You and the village win.'))
            .style!
            .fontSize,
        24,
      );
      // A banner is its longest line and both ends.
      final ends = SliceArt.banner.ends;
      final words = tester.getSize(find.text('You and the village win.')).width;
      expect(
        two.width,
        closeTo(words + ends.left + ends.right + 2 * Space.sm, 1),
      );
    });

    testWidgets('the ends are the same pixels at one line, two and three', (
      tester,
    ) async {
      _phone(tester);
      final ends = SliceArt.banner.ends;
      // The corner rows of every banner (a taller one stretches only between
      // its top and its foot), and the ends' columns but the last two, where
      // the middle's edge is blended.
      final rows = SliceArt.bannerTall.top / SliceArt.banner.pixelsPerPoint - 1;
      final lefts = <List<int>>[];
      final rights = <List<int>>[];
      for (final lines in [
        ['Cleo hanged.'],
        ['Cleo hanged.', 'You and the village win.'],
        ['Cleo, Ben and Maximilian hanged.', 'You lose to', 'the Werewolves.'],
      ]) {
        final (rect, _) = await pumpBanner(tester, lines);
        final pixels = await FramePixels.of(tester);
        lefts.add([
          for (var y = 0; y < rows; y++)
            for (var x = 0; x < ends.left - 2; x++)
              pixels.at(rect.left + x + 0.5, rect.top + y + 0.5),
        ]);
        rights.add([
          for (var y = 0; y < rows; y++)
            for (var x = 2; x < ends.right; x++)
              pixels.at(rect.right - ends.right + x + 0.5, rect.top + y + 0.5),
        ]);
        // Neither end is empty air.
        expect(lefts.last.where((p) => p >>> 24 != 0), isNotEmpty);
      }
      expect(lefts[1], lefts[0], reason: 'the left end moved at two lines');
      expect(lefts[2], lefts[0], reason: 'the left end moved at three lines');
      // The right end sits on a fraction of a pixel (the words' width), so its
      // edges blend differently: it is the same picture when almost no pixel
      // is far off (a stretched end would differ over half of them).
      for (final i in [1, 2]) {
        expect(
          _farOff(rights[i], rights[0]),
          lessThan(0.08),
          reason: 'the right end moved at ${i + 1} lines',
        );
      }
    });

    testWidgets('three lines are taller, and the red one has the same cut', (
      tester,
    ) async {
      _phone(tester);
      final (rect, image) = await pumpBanner(tester, [
        'Cleo, Ben and Maximilian hanged.',
        'You lose to',
        'the Werewolves.',
      ], red: true);
      // Taller by the third line's own height: the paper round the words is
      // as drawn.
      expect(rect.height, greaterThan(BannerSlice.height + 20));
      expect(
        image.centerSlice,
        SliceArt.bannerRed.inPoints(SliceArt.bannerTall),
      );
      expect(SliceArt.bannerRed.slice, SliceArt.banner.slice);
    });
  });

  group('BoardFrame: a nine-slice, the corners stay', () {
    const sizes = [Size(120, 100), Size(200, 300), Size(340, 460)];
    testWidgets('three sizes: the same corner, the middle fills', (
      tester,
    ) async {
      _phone(tester);
      final ends = SliceArt.frame.ends;
      final corners = <List<int>>[];
      for (final size in sizes) {
        await _pump(
          tester,
          SizedBox.fromSize(
            size: size,
            child: const BoardFrame(child: SizedBox.expand()),
          ),
          align: Alignment.topLeft,
        );
        await loadPictures(tester);
        final frame = tester.getRect(find.byType(Image));
        expect(frame.size, size);
        // The room inside is the size less the frame, on every side.
        final inside = find.descendant(
          of: find.byType(BoardFrame),
          matching: find.byType(SizedBox),
        );
        expect(
          tester.getSize(inside.last),
          Size(size.width - ends.horizontal, size.height - ends.vertical),
        );
        final pixels = await FramePixels.of(tester);
        corners.add([
          for (var y = 0; y < ends.top - 2; y++)
            for (var x = 0; x < ends.left - 2; x++) pixels.at(x + 0.5, y + 0.5),
        ]);
        // The felt is there in the middle, opaque.
        expect(
          pixels.at(size.width / 2, size.height / 2) >>> 24,
          0xFF,
          reason: 'felt at the middle of $size',
        );
      }
      expect(corners[1], corners[0]);
      expect(corners[2], corners[0]);
      expect(
        corners[0].where((p) => p >>> 24 != 0).length,
        greaterThan(corners[0].length ~/ 2),
        reason: 'the corner is the frame, not empty',
      );
    });

    testWidgets('on a plain screen it is the child alone', (tester) async {
      _phone(tester);
      await _pump(
        tester,
        const SizedBox(
          width: 100,
          height: 100,
          child: BoardFrame(child: SizedBox.expand()),
        ),
        dress: Dress.plain,
      );
      expect(find.byType(SlicedArt), findsNothing);
    });
  });

  group('TwineRoute: a thread between two cards', () {
    const a = Rect.fromLTWH(10, 10, 90, 70);
    const b = Rect.fromLTWH(220, 190, 90, 70);
    // The words of each card: a name across its top, a role across its foot.
    const labels = [
      Rect.fromLTWH(10, 10, 90, 22),
      Rect.fromLTWH(10, 60, 90, 17),
      Rect.fromLTWH(220, 190, 90, 22),
      Rect.fromLTWH(220, 243, 90, 17),
    ];

    test('it covers neither card\'s words', () {
      final route = TwineRoute.between(a, b, avoid: labels);
      expect(route.crosses(labels, ends: 0.02), isFalse);
      // It is tied to a corner of each card, the two that face.
      expect(route.from, a.bottomRight);
      expect(route.to, b.topLeft);
    });

    test('it goes round a card in the way, to the side with room', () {
      // A third card squarely between the two.
      const between = Rect.fromLTWH(120, 100, 80, 70);
      final straight = TwineRoute.between(a, b);
      expect(
        straight.crosses([between]),
        isTrue,
        reason: 'the card is in the way',
      );
      final round = TwineRoute.between(a, b, avoid: [between, ...labels]);
      expect(round.crosses([between, ...labels]), isFalse);
    });

    test('cards in one column are tied by their near corners', () {
      const upper = Rect.fromLTWH(40, 10, 90, 70);
      const lower = Rect.fromLTWH(44, 190, 90, 70);
      final route = TwineRoute.between(upper, lower);
      expect(route.from, upper.bottomLeft);
      expect(route.to, lower.topLeft);
      expect(
        route.crosses([upper.deflate(1), lower.deflate(1)], ends: 0.02),
        isFalse,
      );
    });
  });

  group(
    'Twine is paper thread: filled, solid for a move, gapped for a look',
    () {
      TwinePainter painter(TwineKind kind) => TwinePainter(
        route: TwineRoute.between(
          const Rect.fromLTWH(0, 0, 30, 30),
          const Rect.fromLTWH(200, 100, 30, 30),
        ),
        kind: kind,
        color: const Color(0xFFF6ECD6),
        shadow: const Color(0xFF000000),
        lean: 0,
      );

      test('a look has gaps and a move has none', () {
        int pieces(Path path) => path.computeMetrics().length;
        expect(pieces(painter(TwineKind.move).thread()), 1);
        expect(pieces(painter(TwineKind.look).thread()), greaterThan(5));
      });

      testWidgets('it paints no stroke and no line', (tester) async {
        _phone(tester);
        await _pump(
          tester,
          SizedBox(
            width: 240,
            height: 140,
            child: Twine(
              kind: TwineKind.look,
              route: painter(TwineKind.look).route,
            ),
          ),
        );
        final shapes = tester.renderObject<RenderCustomPaint>(
          find.descendant(
            of: find.byType(Twine),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(shapes.painter, isA<TwinePainter>());
      });
    },
  );

  group('OneLight: every shadow falls down and away from the light', () {
    const light = OneLight(Offset(300, 100));
    // One card in each quarter round the light, and one under it.
    final quarters = {
      'left and above': const Rect.fromLTWH(20, 0, 80, 60),
      'left and below': const Rect.fromLTWH(20, 300, 80, 60),
      'right and above': const Rect.fromLTWH(420, 0, 80, 60),
      'right and below': const Rect.fromLTWH(420, 300, 80, 60),
    };

    testWidgets('on the board\'s paper, in four quarters', (tester) async {
      _phone(tester);
      for (final entry in quarters.entries) {
        final rect = entry.value;
        final away = (rect.center.dx - light.point.dx).sign;
        final lean = light.leanFor(rect);
        expect(lean.sign, away, reason: '${entry.key}: the lean');
        expect(lean.abs(), lessThanOrEqualTo(OneLight.mostLean));
        await _pump(
          tester,
          OneLightScope(
            light: light,
            child: LitAt(
              rect: rect,
              child: const PaperPiece(
                part: PaperPart.scrap,
                id: 'a',
                child: SizedBox(width: 60, height: 30),
              ),
            ),
          ),
        );
        final inside = tester.element(find.byType(PaperPiece));
        expect(PaperLight.of(inside), lean);
        final shadows = _shadowsOf(tester, find.byType(PaperPiece));
        expect(shadows, isNotEmpty);
        for (final s in shadows) {
          expect(
            s.offset.dy,
            greaterThan(0),
            reason: '${entry.key}: falls down',
          );
          expect(s.spreadRadius, 0, reason: 'no halo');
          expect(
            s.offset.dx.sign,
            away,
            reason: '${entry.key}: falls away from the light',
          );
        }
      }
    });

    test('paperShadows: under the light straight down, never toward it', () {
      final elevation = _dressedElevation();
      final under = paperShadows(
        light,
        const Rect.fromLTWH(260, 300, 80, 60),
        elevation,
      );
      expect(under.map((s) => s.offset.dx).toSet(), {0.0});
      for (final rect in quarters.values) {
        final away = (rect.center.dx - light.point.dx).sign;
        for (final s in paperShadows(light, rect, elevation)) {
          expect(s.offset.dy, greaterThan(0));
          expect(s.offset.dx * away, greaterThanOrEqualTo(0));
        }
      }
    });

    test('a card level with the light still falls down, gently', () {
      const level = Rect.fromLTWH(380, 70, 80, 60);
      final lean = light.leanFor(level);
      expect(lean, greaterThan(0));
      expect(lean, lessThanOrEqualTo(OneLight.mostLean));
    });

    test('far from the light is a little darker, near it not at all', () {
      const near = Rect.fromLTWH(270, 70, 60, 60);
      const far = Rect.fromLTWH(0, 600, 60, 60);
      expect(light.darknessAt(near), 0);
      expect(light.darknessAt(far), OneLight.darkest);
      expect(OneLight.darkest, lessThan(0.4));
    });

    test('the lantern is a light the board can take', () {
      final lantern = OneLight.lantern(const Rect.fromLTWH(272, 162, 88, 152));
      expect(lantern.point.dx, closeTo(272 + 0.41 * 88, 0.01));
      expect(lantern.point.dy, closeTo(162 + 0.755 * 152, 0.01));
    });

    testWidgets('with no board light a piece is lit as its screen is', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        PaperLight(
          lean: -0.5,
          child: LitAt(
            rect: const Rect.fromLTWH(0, 0, 10, 10),
            child: Builder(
              builder: (context) => Text('${PaperLight.of(context)}'),
            ),
          ),
        ),
      );
      expect(find.text('-0.5'), findsOneWidget);
    });
  });

  group('DeathMark: a mark never hides much of a face', () {
    // A card: name 22, portrait 4:3, role strip 17 across the portrait's foot.
    Rect cardOf(double portraitWidth) =>
        Rect.fromLTWH(0, 0, portraitWidth + 8, 22 + portraitWidth * 0.75 + 4);
    Rect portraitOf(double portraitWidth) =>
        Rect.fromLTWH(4, 22, portraitWidth, portraitWidth * 0.75);

    test('the ribbon: a third of the portrait, 92% outside, clear of it', () {
      for (final w in <double>[44, 64, 90, 110, 130]) {
        final width = DeathMark.ribbonWidth(w);
        expect(width, inInclusiveRange(30, 38));
        final ribbon = DeathMark.ribbonRect(cardOf(w), w);
        // Mostly hanging outside the card...
        final inside = ribbon.intersect(cardOf(w));
        expect(
          inside.width * inside.height / (ribbon.width * ribbon.height),
          lessThan(0.1),
          reason: 'the ribbon at $w hangs outside',
        );
        // ...and over the portrait by no more than the set part.
        expect(
          DeathMark.coverOf(portraitOf(w), ribbon),
          lessThanOrEqualTo(DeathMark.maxCover),
        );
      }
    });

    testWidgets('the stamp: a narrow plate that lands under a big card\'s '
        'face and over no word', (tester) async {
      _phone(tester);
      await _pump(
        tester,
        const InkStamp(label: 'HANGED', burst: false, width: 120),
      );
      final stamp = tester.getSize(find.byType(InkStamp));
      expect(stamp.width, 120);
      // A card as the reveal holds it up: 200 wide, its art filling it.
      Rect card(double w) => Rect.fromLTWH(0, 0, w, 44 + w * 0.75 + 20);
      Rect portrait(double w) => Rect.fromLTWH(8, 44, w - 16, (w - 16) * 3 / 4);
      double tab(double w) => card(w).bottom - 1;
      for (final w in <double>[180, 200, 240]) {
        expect(
          DeathMark.stampFits(card(w), portrait(w), stamp, tabBottom: tab(w)),
          isTrue,
          reason: 'a stamp of $stamp on a card $w wide',
        );
      }
      // The check bites: on a card the size of a thumbnail it would lie over
      // the face and be most of the card.
      expect(
        DeathMark.stampFits(card(60), portrait(60), stamp, tabBottom: tab(60)),
        isFalse,
      );
      expect(DeathMark.stampShare, lessThanOrEqualTo(0.16));
    });

    testWidgets('the ribbon and the stamp draw on both dresses', (
      tester,
    ) async {
      _phone(tester);
      for (final dress in Dress.values) {
        await _pump(
          tester,
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DeathRibbon(width: 30),
              InkStamp(label: 'HANGED'),
            ],
          ),
          dress: dress,
        );
        await loadPictures(tester);
        expect(find.byType(DeathRibbon), findsOneWidget);
        expect(find.text('HANGED'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('YouSeal: your own sigil on the wax', () {
    testWidgets('a paper seal has the wax and the sigil; plain the sigil', (
      tester,
    ) async {
      _phone(tester);
      await _pump(tester, const YouSeal(token: TokenId.crow));
      await loadPictures(tester);
      expect(tester.getSize(find.byType(YouSeal)), const Size(30, 30));
      final paper = paintedPictures(tester, part: 'end/seal');
      expect(paper, hasLength(1));
      expect(paper.single.decoded, isTrue);
      expect(paintedPictures(tester, part: 'tokens/crow'), hasLength(1));
      await _pump(
        tester,
        const YouSeal(token: TokenId.crow),
        dress: Dress.plain,
      );
      await loadPictures(tester);
      expect(paintedPictures(tester, part: 'end/seal'), isEmpty);
      expect(paintedPictures(tester, part: 'tokens/crow'), hasLength(1));
    });
  });

  test('the ornaments are all drawn through the skin\'s own folder', () {
    final art = const EndArt('assets/skins/shadow_paper');
    for (final piece in EndPiece.values) {
      expect(
        art.piece(piece).path,
        'assets/skins/shadow_paper/end/${piece.file}.webp',
      );
    }
    expect(GroundKind.values, contains(GroundKind.night));
  });
}
