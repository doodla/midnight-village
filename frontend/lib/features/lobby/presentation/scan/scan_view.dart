import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/secondary_button.dart';
import '../../../../design_system/primitives/viewfinder.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/table_link.dart';
import 'code_scanner.dart';

/// 01b Scan: the camera, in a paper window on the night's ground, and
/// nothing to read while it looks (Back is a glyph, so is the light, where
/// the camera has one).
///
/// - The camera is [scanner]'s, started when this is built and stopped the
///   moment it is read or this goes.
/// - A code that is a table's link or a bare code ([tableCodeFrom]) is
///   "found": the camera stops, the window's corners close in, the code
///   stands in the window, and [onCode] is told at once (no beat is waited
///   out). Anything else a camera sees is ignored, silently.
/// - Where the camera cannot be used (refused, none, a page that may not):
///   the window shows it is off, one calm line says so, and "Type the code"
///   ([onType]) is the way on. Never a dead end.
/// - [joining]: the table is being joined with the code that was found.
class ScanView extends StatefulWidget {
  const ScanView({
    super.key,
    required this.makeScanner,
    this.code,
    required this.onCode,
    required this.onBack,
    required this.onType,
    this.joining = false,
  });

  /// Makes the camera when this opens (nothing is touched before), and this
  /// ends it with the screen.
  final CodeScannerFactory makeScanner;

  /// A code already read (this screen was rebuilt while its join was on its
  /// way): shown as found, with no camera.
  final String? code;

  /// A table's code, in capitals, was read.
  final ValueChanged<String> onCode;

  /// The Back glyph (the phone's Back is the caller's [BackHandler]).
  final VoidCallback onBack;

  /// "Type the code": the camera cannot be used.
  final VoidCallback onType;

  final bool joining;

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  late String? _code = widget.code;
  ScanProblem? _problem;
  CodeScanner? _scanner;
  Widget? _camera;

  @override
  void initState() {
    super.initState();
    if (_code == null) {
      final scanner = _scanner = widget.makeScanner();
      _camera = scanner.view(onText: _seen, onProblem: _failed);
    }
  }

  void _seen(String text) {
    if (_code != null || _problem != null) return;
    final code = tableCodeFrom(text);
    if (code == null) return;
    setState(() => _code = code);
    _scanner?.stop();
    widget.onCode(code);
  }

  void _failed(ScanProblem problem) {
    if (!mounted || _code != null) return;
    setState(() => _problem = problem);
  }

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = skin.ground(GroundKind.night);
    final problem = _problem;
    final code = _code;
    final paper = skin.ground(GroundKind.paper);

    final Widget inside;
    if (code != null) {
      // The code stands in the window, in the paper's ink; the table is on
      // its way once a name is typed.
      inside = ColoredBox(
        key: const ValueKey('found'),
        color: ground.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.md,
              children: [
                FitLine(
                  code,
                  style: skin.typography.heroCode.copyWith(color: paper.text),
                ),
                if (widget.joining)
                  BusyMark(size: Space.xl + 4, color: paper.text),
              ],
            ),
          ),
        ),
      );
    } else if (problem != null) {
      inside = Center(
        key: const ValueKey('off'),
        child: Icon(
          Icons.videocam_off_outlined,
          size: 56,
          color: ground.faintText,
        ),
      );
    } else {
      inside = KeyedSubtree(key: const ValueKey('looking'), child: _camera!);
    }

    return ScreenFrame(
      ground: GroundKind.night,
      fitsHeight: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.xl,
        children: [
          Row(
            children: [
              GlyphButton(
                glyph: (ink) => Icon(Icons.arrow_back, color: ink),
                semanticLabel: ScanCopy.back,
                onPressed: widget.onBack,
                size: ButtonSize.regular,
              ),
              const Spacer(),
              if (_scanner case final scanner? when code == null)
                ValueListenableBuilder(
                  valueListenable: scanner.light,
                  builder: (context, light, _) =>
                      light == LightState.unavailable
                      ? const SizedBox.shrink()
                      : GlyphButton(
                          glyph: (ink) => Icon(Icons.flash_on, color: ink),
                          semanticLabel: ScanCopy.light,
                          lit: light == LightState.on,
                          onPressed: scanner.toggleLight,
                          size: ButtonSize.regular,
                        ),
                ),
            ],
          ),
          // The window and its one line, in the middle of what is left.
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: Space.xl,
                children: [
                  Flexible(
                    child: Semantics(
                      label:
                          code ?? (problem == null ? ScanCopy.looking : null),
                      liveRegion: true,
                      child: Viewfinder(
                        found: code != null,
                        child: AnimatedSwitcher(
                          duration: Motion.within(context, Motion.quick),
                          child: inside,
                        ),
                      ),
                    ),
                  ),
                  if (problem != null)
                    Semantics(
                      liveRegion: true,
                      child: FitWords(
                        ScanCopy.cameraOff,
                        textAlign: TextAlign.center,
                        style: skin.typography.bodyLarge.copyWith(
                          color: ground.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (problem != null)
          PrimaryButton(
            label: ScanCopy.typeCode,
            onPressed: widget.onType,
            size: ButtonSize.large,
          ),
      ],
    );
  }
}
