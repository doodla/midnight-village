part of 'band.dart';

// The band that carries the vote's clock (`TimerBand`) and the clock's
// figure. Part of band.dart: the same library.

/// The vote's countdown, edge to edge at the top of the screen (put it in
/// `ScreenFrame.topSlot`): a strip of night with the number, and a bar along
/// its foot, [remaining] of it lit in the danger line. It shows what it is
/// given and stops at 0. (The talk's clock is `SquareSky`.)
///
/// The digits stand alone: the mock's caption ("seconds to choose") is cut
/// (first-time play spec, copy rule 9). The number is set smaller rather than
/// pushed off a narrow phone. The screen's [title] sits beside the number, on
/// two lines at most, where the two fit side by side, and under it where they
/// do not (large text, a narrow phone).
///
/// Nothing is drawn that is not known: with no share of the stage (null
/// [remaining]: an untimed stage) the bar is unlit; with no deadline (null
/// [secondsLeft]) there is no number either.
class TimerBand extends StatelessWidget {
  const TimerBand.bar({
    super.key,
    required this.secondsLeft,
    required this.remaining,
    this.title,
    this.semanticLabel,
  });

  /// Null: the stage has no deadline, and nothing is counted.
  final int? secondsLeft;

  /// How much of the phase is left, 0 to 1; null when unknown.
  final double? remaining;

  /// The screen's headline, beside or under the number.
  final String? title;

  /// Read out instead of the number.
  final String? semanticLabel;

  /// The bar's thickness (S09).
  static const barHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;
    final number = seconds == null ? null : WorldTimer.format(seconds);
    return _bar(context, number);
  }

  /// The number and the title: side by side when the title fits beside the
  /// number on two lines, else the title under it.
  Widget _heading(
    BuildContext context,
    String? number,
    TextStyle numberStyle,
    Color titleColor,
  ) {
    final title = this.title;
    final spoken = semanticLabel ?? number;
    Widget digits(String number, {double? width}) => Semantics(
      label: spoken,
      excludeSemantics: true,
      child: width == null
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: ClockFigure(number, style: numberStyle),
            )
          : SizedBox(
              width: width,
              child: ClockFigure(number, style: numberStyle),
            ),
    );
    if (title == null) {
      return number == null ? const SizedBox.shrink() : digits(number);
    }
    final titleStyle = context.skin.typography.screenTitle.copyWith(
      color: titleColor,
    );
    final head = Semantics(
      header: true,
      child: FitWords(title, style: titleStyle, maxLines: 2),
    );
    if (number == null) return head;
    return LayoutBuilder(
      builder: (context, room) {
        final scaler = MediaQuery.textScalerOf(context);
        // Side by side or stacked is decided on the number's shape
        // ("0:00"): the band's height holds still while the clock ticks (a
        // narrower "4:54" no longer stacks or unstacks the title, and with
        // it moves the body under the band). The number itself takes its own
        // width.
        final shapeWidth = ClockFigure.width(
          ClockFigure.shape(number),
          numberStyle,
          scaler,
        ).ceilToDouble();
        final numberWidth = ClockFigure.width(
          number,
          numberStyle,
          scaler,
        ).ceilToDouble();
        final beside = room.maxWidth - shapeWidth - Space.lg;
        if (_fitsTwoLines(title, titleStyle, scaler, beside)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: Space.lg,
            children: [
              digits(number, width: numberWidth),
              Expanded(child: head),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: Space.xs,
          children: [digits(number), head],
        );
      },
    );
  }

  static double _width(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// [text] wraps between words into [room] on two lines at most.
  static bool _fitsTwoLines(
    String text,
    TextStyle style,
    TextScaler scaler,
    double room,
  ) {
    if (room <= 0) return false;
    final longestWord = text
        .split(' ')
        .map((w) => _width(w, style, scaler))
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (longestWord > room) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: room);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines <= 2;
  }

  Widget _bar(BuildContext context, String? number) {
    final skin = context.skin;
    final dressed = context.dress.isPaper;
    final top = MediaQuery.paddingOf(context).top;
    final lit = remaining;
    return GroundScope(
      ground: GroundKind.night,
      fill: true,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: Space.md,
          children: [
            Padding(
              padding: dressed
                  ? EdgeInsets.fromLTRB(Space.md, Space.lg + top, Space.md, 0)
                  : EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.xl + 2 + top,
                      Space.gutter,
                      0,
                    ),
              child: PaperBanner(
                id: #vote,
                child: (context) => _heading(
                  context,
                  number,
                  dressed
                      ? skin.typography.timerVote.copyWith(
                          color: context.ground.text,
                        )
                      : skin.typography.timerVote,
                  context.ground.text,
                ),
              ),
            ),
            _strip(context, number, lit),
          ],
        ),
      ),
    );
  }

  /// The time left: a bar of the ground lit along its length (dressed up, a
  /// strip of torn paper, set in from the margin).
  Widget _strip(BuildContext context, String? number, double? lit) {
    final night = context.skin.night;
    final fill = FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: number == null || lit == null
          ? 0
          : lit.clamp(0, 1).toDouble(),
      child: ColoredBox(color: night.dangerLine),
    );
    if (!context.dress.isPaper) {
      return SizedBox(
        height: barHeight,
        child: ColoredBox(color: night.hairline, child: fill),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: SizedBox(
        height: barHeight,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: night.ground,
            shape: DeckleBorder(
              seed: deckleSeed(#bar),
              depth: context.skin.parts.barDepth,
            ),
          ),
          child: fill,
        ),
      ),
    );
  }
}

/// A clock's figure on one line, set smaller rather than broken: the number
/// at [style], and its unit ("14 s": the space and what follows) at a fraction
/// of it, so a hero-size number does not carry a hero-size "s".
class ClockFigure extends StatelessWidget {
  const ClockFigure(
    this.text, {
    super.key,
    required this.style,
    this.alignment = AlignmentDirectional.centerStart,
    this.textScaler,
  });

  final String text;
  final TextStyle style;

  /// Where the figure sits in a box wider than it.
  final AlignmentGeometry alignment;

  /// Null: the text's own scale (the night's number keeps its size: it is
  /// given [TextScaler.noScaling]).
  final TextScaler? textScaler;

  /// The unit's size against the number's.
  static const unitShare = 0.4;

  /// The figure as spans: the number, then the unit set smaller.
  static TextSpan span(String text, TextStyle style) {
    final space = text.lastIndexOf(' ');
    final size = style.fontSize;
    if (space < 0 || size == null) return TextSpan(text: text);
    // The space goes with the unit, at its size: a hero-size gap would
    // part them.
    return TextSpan(
      text: text.substring(0, space),
      children: [
        TextSpan(
          text: text.substring(space),
          style: TextStyle(fontSize: size * unitShare),
        ),
      ],
    );
  }

  /// [text] with every digit a zero: the clock's shape, whatever it reads
  /// (a digit wider than the zero is set a touch smaller in that room).
  static String shape(String text) => text.replaceAll(RegExp(r'\d'), '0');

  /// The figure's natural width, measured as it is drawn.
  static double width(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(style: style, children: [span(text, style)]),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        span(text, style),
        textScaler: textScaler,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}
