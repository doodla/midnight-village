import 'package:flutter/widgets.dart';

/// One step of a single wave across a row of things (the `night_choose` cue
/// across the board as it opens, `vote_lock` across the vote rows): when
/// [play] is true as it is built, or turns true, [child] lifts [distance] and
/// settles, [index] steps of [stagger] after the first (first-time play
/// spec, section 2). It runs once, and not at all with reduced motion.
class CueWave extends StatefulWidget {
  const CueWave({
    super.key,
    required this.play,
    required this.index,
    required this.distance,
    required this.child,
  });

  final bool play;
  final int index;
  final double distance;
  final Widget child;

  /// One thing's lift and fall.
  static const each = Duration(milliseconds: 120);

  /// Between one thing's start and the next's.
  static const stagger = Duration(milliseconds: 90);

  /// The night board's lift, and the vote rows' nudge.
  static const boardLift = 8.0;
  static const rowNudge = 6.0;

  @override
  State<CueWave> createState() => _CueWaveState();
}

class _CueWaveState extends State<CueWave> with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(vsync: this, duration: _length);

  /// The whole wave up to and including this thing's step.
  Duration get _length => CueWave.stagger * widget.index + CueWave.each;

  @override
  void initState() {
    super.initState();
    if (widget.play) _start();
  }

  @override
  void didUpdateWidget(CueWave old) {
    super.didUpdateWidget(old);
    // The same element can be another card's step after the board wraps.
    if (old.index != widget.index) _wave.duration = _length;
    if (widget.play && !old.play) _start();
  }

  void _start() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !MediaQuery.disableAnimationsOf(context)) {
      _wave.forward(from: 0);
    }
  });

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _wave.duration!.inMicroseconds;
    final start = (CueWave.stagger * widget.index).inMicroseconds / total;
    // Up and back down within this thing's own step of the wave.
    final lift = TweenSequence([
      if (start > 0)
        TweenSequenceItem(tween: ConstantTween(0.0), weight: start),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -widget.distance),
        weight: (1 - start) / 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -widget.distance, end: 0.0),
        weight: (1 - start) / 2,
      ),
    ]).animate(_wave);
    // Two layers: the moving one (only its transform is redone each frame)
    // and the thing's own, painted once.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: lift,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, lift.value), child: child),
        // The thing lifts as one picture: the paper in it is painted once, not
        // again every frame the wave moves it.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
