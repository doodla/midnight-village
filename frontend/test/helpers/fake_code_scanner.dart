import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:midnight_village/design_system/primitives/qr_picture.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/features/lobby/presentation/scan/code_scanner.dart';

/// A camera a test or a picture drives: [see] is a code the camera sees. It
/// remembers what the screen did with it (started, stopped, ended), so a test
/// can say the camera is off the moment the screen leaves.
class FakeCodeScanner implements CodeScanner {
  /// [problem]: the camera cannot be used (the screen is told when it builds
  /// the view). [lit]: the camera has a light, in this state. [frame]: what
  /// the camera shows (the gallery's picture of a table with a code on it).
  FakeCodeScanner({
    this.problem,
    LightState lit = LightState.unavailable,
    this.frame = const FakeCameraFrame(),
  }) : _light = ValueNotifier(lit);

  final ScanProblem? problem;
  final Widget frame;
  final ValueNotifier<LightState> _light;

  /// The camera is live (its view is on screen and it was not stopped).
  var started = false;
  var stopped = false;
  var disposed = false;
  var lightToggles = 0;

  ValueChanged<String>? _onText;

  /// The camera sees a code with [text].
  void see(String text) => _onText?.call(text);

  @override
  Widget view({
    required ValueChanged<String> onText,
    required ValueChanged<ScanProblem> onProblem,
  }) {
    _onText = onText;
    final failed = problem;
    if (failed != null) {
      return Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onProblem(failed),
          );
          return const SizedBox.shrink();
        },
      );
    }
    started = true;
    return frame;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    started = false;
  }

  @override
  ValueListenable<LightState> get light => _light;

  @override
  Future<void> toggleLight() async {
    lightToggles++;
    _light.value = _light.value == LightState.on
        ? LightState.off
        : LightState.on;
  }

  @override
  void dispose() {
    disposed = true;
    started = false;
    _light.dispose();
  }
}

/// A picture of what a camera would show: a table, and on it a paper card
/// with a table's QR code, held a little off the square.
class FakeCameraFrame extends StatelessWidget {
  const FakeCameraFrame({
    super.key,
    this.link = 'https://midnight.example/join/V9YC2J',
  });

  final String link;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A3326), Color(0xFF1E1A14)],
      ),
    ),
    child: Center(
      child: Transform.rotate(
        angle: -0.07,
        child: Container(
          width: 150,
          height: 150,
          color: const Color(0xFFF1E6CF),
          padding: const EdgeInsets.all(6),
          child: GroundScope(
            ground: GroundKind.paper,
            child: QrPicture(data: link, side: 138),
          ),
        ),
      ),
    ),
  );
}
